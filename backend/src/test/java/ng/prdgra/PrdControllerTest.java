package ng.prdgra;

import ng.prdgra.config.SecurityConfig;
import ng.prdgra.dto.PageResponse;
import ng.prdgra.dto.PrdRequest;
import ng.prdgra.dto.PrdResponse;
import ng.prdgra.repository.UserRepository;
import ng.prdgra.security.JwtAuthFilter;
import ng.prdgra.security.JwtService;
import ng.prdgra.security.RateLimitFilter;
import ng.prdgra.service.PrdService;
import ng.prdgra.controller.PrdController;
import ng.prdgra.controller.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

// @WebMvcTest carrega apenas a camada web — sem JPA, DataSource, Flyway ou Caffeine.
// Todos os beans de infraestrutura sao mockados explicitamente abaixo.
@WebMvcTest(controllers = { PrdController.class, GlobalExceptionHandler.class })
@Import({ SecurityConfig.class, JwtAuthFilter.class, RateLimitFilter.class })
class PrdControllerTest {

    @Autowired
    private MockMvc mockMvc;

    // Servicos de negocio
    @MockBean
    private PrdService prdService;

    // Dependencias da camada de seguranca (nao carregadas pelo @WebMvcTest)
    @MockBean
    private JwtService jwtService;

    @MockBean
    private UserRepository userRepository;

    // CacheManager necessario para PrdService (mesmo mockado, SecurityConfig o referencia via contexto)
    @MockBean
    private org.springframework.cache.CacheManager cacheManager;

    // ObjectMapper ja e provido pelo @WebMvcTest — nao precisa ser mockado

    private PrdResponse samplePrd(UUID id) {
        return new PrdResponse(id, "My PRD", "desc",
                List.of("Java"), List.of("Obj1"), "DRAFT",
                Instant.now(), Instant.now());
    }

    private PageResponse<PrdResponse> singlePageResponse(PrdResponse prd) {
        return new PageResponse<>(List.of(prd), 0, 20, 1, 1, true);
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void listPrds_returnsOk() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.listByUser(eq("test@example.com"), anyInt(), anyInt()))
                .thenReturn(singlePageResponse(samplePrd(id)));

        mockMvc.perform(get("/prds"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("My PRD"));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void createPrd_returnsCreated() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.create(any(PrdRequest.class), eq("test@example.com"))).thenReturn(samplePrd(id));

        mockMvc.perform(post("/prds")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"New PRD","description":"desc",
                                "stack":["Next.js"],"objectives":["Fast"]}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("My PRD"));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void createPrd_missingTitle_returns400() throws Exception {
        mockMvc.perform(post("/prds")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"description":"desc","stack":["Java"],"objectives":["Obj"]}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void findById_returnsOk() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.findById(id, "test@example.com")).thenReturn(samplePrd(id));

        mockMvc.perform(get("/prds/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void findById_notOwner_returns404() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.findById(id, "test@example.com"))
                .thenThrow(new NoSuchElementException("PRD not found"));

        mockMvc.perform(get("/prds/" + id))
                .andExpect(status().isNotFound());
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void updatePrd_returnsOk() throws Exception {
        UUID id = UUID.randomUUID();
        var updated = new PrdResponse(id, "Updated", "new desc",
                List.of("Go"), List.of("Perf"), "REVIEW",
                Instant.now(), Instant.now());
        when(prdService.update(eq(id), any(PrdRequest.class), eq("test@example.com"))).thenReturn(updated);

        mockMvc.perform(put("/prds/" + id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Updated","description":"new desc",
                                "stack":["Go"],"objectives":["Perf"],"status":"REVIEW"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Updated"))
                .andExpect(jsonPath("$.status").value("REVIEW"));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void deletePrd_returnsNoContent() throws Exception {
        UUID id = UUID.randomUUID();
        doNothing().when(prdService).delete(id, "test@example.com");

        mockMvc.perform(delete("/prds/" + id))
                .andExpect(status().isNoContent());
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void deletePrd_notOwner_returns404() throws Exception {
        UUID id = UUID.randomUUID();
        doThrow(new NoSuchElementException("PRD not found"))
                .when(prdService).delete(id, "test@example.com");

        mockMvc.perform(delete("/prds/" + id))
                .andExpect(status().isNotFound());
    }

    @Test
    void listPrds_unauthenticated_returns401() throws Exception {
        mockMvc.perform(get("/prds"))
                .andExpect(status().isUnauthorized());
    }
}
