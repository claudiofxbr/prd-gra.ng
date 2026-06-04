package ng.prdgra;

import ng.prdgra.repository.PrdRepository;
import ng.prdgra.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class PrdIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("spring.datasource.hikari.data-source-properties.sslmode", () -> "disable");
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PrdRepository prdRepository;

    @BeforeEach
    void setUp() {
        prdRepository.deleteAll();
        userRepository.deleteAll();
    }

    private String registerAndLogin(String email) throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Test User","email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk());

        var result = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"password123"}
                                """.formatted(email)))
                .andExpect(status().isOk())
                .andReturn();

        // Token é entregue via Set-Cookie HttpOnly — extrai o valor do cookie prdgra_token
        String setCookieHeader = result.getResponse().getHeader("Set-Cookie");
        if (setCookieHeader != null && setCookieHeader.contains("prdgra_token=")) {
            String cookiePart = java.util.Arrays.stream(setCookieHeader.split(";"))
                    .map(String::trim)
                    .filter(s -> s.startsWith("prdgra_token="))
                    .findFirst()
                    .orElseThrow(() -> new IllegalStateException("Cookie prdgra_token não encontrado"));
            return cookiePart.substring("prdgra_token=".length());
        }
        throw new IllegalStateException("Set-Cookie header ausente na resposta de login");
    }

    @Test
    void fullFlow_registerLoginCreateListPrd() throws Exception {
        String token = registerAndLogin("int@test.com");

        mockMvc.perform(post("/api/prds")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"My PRD","description":"A test PRD",
                                "stack":["Java","Next.js"],"objectives":["Fast","Secure"]}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("My PRD"))
                .andExpect(jsonPath("$.status").value("DRAFT"));

        mockMvc.perform(get("/api/prds")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.content[0].title").value("My PRD"));
    }

    @Test
    void updatePrd_changesStatusAndTitle() throws Exception {
        String token = registerAndLogin("update@test.com");

        var createResult = mockMvc.perform(post("/api/prds")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Original","stack":["Java"],"objectives":["Obj"]}
                                """))
                .andExpect(status().isCreated())
                .andReturn();

        String id = com.fasterxml.jackson.databind.json.JsonMapper.builder().build()
                .readTree(createResult.getResponse().getContentAsString())
                .get("id").asText();

        mockMvc.perform(put("/api/prds/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Updated","stack":["Go"],"objectives":["Perf"],"status":"REVIEW"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Updated"))
                .andExpect(jsonPath("$.status").value("REVIEW"));
    }

    @Test
    void deletePrd_removesFromList() throws Exception {
        String token = registerAndLogin("delete@test.com");

        var createResult = mockMvc.perform(post("/api/prds")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"To Delete","stack":["Java"],"objectives":["Obj"]}
                                """))
                .andExpect(status().isCreated())
                .andReturn();

        String id = com.fasterxml.jackson.databind.json.JsonMapper.builder().build()
                .readTree(createResult.getResponse().getContentAsString())
                .get("id").asText();

        mockMvc.perform(delete("/api/prds/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/prds")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray())
                .andExpect(jsonPath("$.content").isEmpty())
                .andExpect(jsonPath("$.totalElements").value(0));
    }

    @Test
    void findById_anotherUserCannotAccess() throws Exception {
        String tokenA = registerAndLogin("userA@test.com");
        String tokenB = registerAndLogin("userB@test.com");

        var createResult = mockMvc.perform(post("/api/prds")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"User A PRD","stack":["Java"],"objectives":["Obj"]}
                                """))
                .andExpect(status().isCreated())
                .andReturn();

        String id = com.fasterxml.jackson.databind.json.JsonMapper.builder().build()
                .readTree(createResult.getResponse().getContentAsString())
                .get("id").asText();

        mockMvc.perform(get("/api/prds/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound());
    }

    @Test
    void register_duplicateEmail_returnsConflict() throws Exception {
        registerAndLogin("dup@test.com");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Other","email":"dup@test.com","password":"password123"}
                                """))
                .andExpect(status().isConflict());
    }

    @Test
    void login_wrongPassword_returnsUnauthorized() throws Exception {
        registerAndLogin("wrong@test.com");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"wrong@test.com","password":"senhaErrada"}
                                """))
                .andExpect(status().isUnauthorized());
    }
}
