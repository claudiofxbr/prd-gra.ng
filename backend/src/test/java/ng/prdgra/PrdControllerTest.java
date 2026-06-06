package ng.prdgra;

import ng.prdgra.dto.PageResponse;
import ng.prdgra.dto.PrdRequest;
import ng.prdgra.dto.PrdResponse;
import ng.prdgra.service.PrdService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
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

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PrdControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PrdService prdService;

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

        mockMvc.perform(get("/api/prds"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("My PRD"));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void createPrd_returnsCreated() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.create(any(PrdRequest.class), eq("test@example.com"))).thenReturn(samplePrd(id));

        mockMvc.perform(post("/api/prds")
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
        mockMvc.perform(post("/api/prds")
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

        mockMvc.perform(get("/api/prds/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()));
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void findById_notOwner_returns404() throws Exception {
        UUID id = UUID.randomUUID();
        when(prdService.findById(id, "test@example.com"))
                .thenThrow(new NoSuchElementException("PRD not found"));

        mockMvc.perform(get("/api/prds/" + id))
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

        mockMvc.perform(put("/api/prds/" + id)
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

        mockMvc.perform(delete("/api/prds/" + id))
                .andExpect(status().isNoContent());
    }

    @Test
    @WithMockUser(username = "test@example.com")
    void deletePrd_notOwner_returns404() throws Exception {
        UUID id = UUID.randomUUID();
        doThrow(new NoSuchElementException("PRD not found"))
                .when(prdService).delete(id, "test@example.com");

        mockMvc.perform(delete("/api/prds/" + id))
                .andExpect(status().isNotFound());
    }

    @Test
    void listPrds_unauthenticated_returns401() throws Exception {
        mockMvc.perform(get("/api/prds"))
                .andExpect(status().isUnauthorized());
    }
}
