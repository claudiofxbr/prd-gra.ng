package ng.prdgra.service;

import com.github.benmanes.caffeine.cache.Cache;
import lombok.RequiredArgsConstructor;
import ng.prdgra.dto.PageResponse;
import ng.prdgra.dto.PrdRequest;
import ng.prdgra.dto.PrdResponse;
import ng.prdgra.dto.PrdSummaryResponse;
import ng.prdgra.model.converter.StringListConverter;
import ng.prdgra.model.Prd;
import ng.prdgra.model.User;
import ng.prdgra.repository.PrdRepository;
import ng.prdgra.repository.UserRepository;
import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCache;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PrdService {

    private static final int MAX_PAGE_SIZE = 100;

    private final PrdRepository prdRepository;
    private final UserRepository userRepository;
    private final CacheManager cacheManager;

    @Cacheable(value = "prds", key = "#userEmail + '|' + #page + '|' + #size")
    public PageResponse<PrdResponse> listByUser(String userEmail, int page, int size) {
        int safeSize = Math.min(size, MAX_PAGE_SIZE);
        return PageResponse.from(
                prdRepository.findByUserEmail(userEmail, PageRequest.of(page, safeSize)),
                PrdResponse::from);
    }

    @Transactional
    public PrdResponse create(PrdRequest request, String userEmail) {
        User userRef = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new UsernameNotFoundException(userEmail));
        var prd = Prd.builder()
                .title(request.title())
                .description(request.description())
                .stack(request.stack())
                .objectives(request.objectives())
                .user(userRef)
                .createdBy(userRef)
                .modifiedBy(userRef)
                .build();
        @SuppressWarnings("null") Prd saved = prdRepository.save(prd);
        evictUserCache(userEmail);
        return PrdResponse.from(saved);
    }

    @Transactional
    public PrdResponse update(UUID id, PrdRequest request, String userEmail) {
        var prd = prdRepository.findByIdAndUserEmail(id, userEmail)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
        prd.setTitle(request.title());
        prd.setDescription(request.description());
        prd.setStack(request.stack());
        prd.setObjectives(request.objectives());
        prd.setModifiedBy(prd.getUser());
        if (request.status() != null) {
            try {
                prd.setStatus(Prd.PrdStatus.valueOf(request.status()));
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("Status inválido. Valores aceitos: DRAFT, REVIEW, APPROVED");
            }
        }
        @SuppressWarnings("null") Prd saved = prdRepository.save(prd);
        evictUserCache(userEmail);
        return PrdResponse.from(saved);
    }

    @Transactional
    public void delete(UUID id, String userEmail) {
        var prd = prdRepository.findByIdAndUserEmail(id, userEmail)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
        prd.setDeletedAt(Instant.now());
        prd.setDeletedBy(prd.getUser());
        prdRepository.save(prd);
        evictUserCache(userEmail);
    }

    public PrdResponse findById(UUID id, String userEmail) {
        return prdRepository.findByIdAndUserEmail(id, userEmail)
                .map(PrdResponse::from)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
    }

    public PrdSummaryResponse summary(String userEmail) {
        // Contagem por status — inicializa todos os status com 0 para garantir chaves no JSON
        Map<String, Long> byStatus = new HashMap<>();
        for (Prd.PrdStatus s : Prd.PrdStatus.values()) {
            byStatus.put(s.name(), 0L);
        }
        for (Object[] row : prdRepository.countByStatusForUser(userEmail)) {
            byStatus.put(String.valueOf(row[0]), ((Number) row[1]).longValue());
        }
        int total = byStatus.values().stream().mapToInt(Long::intValue).sum();

        // Top stacks — cada linha é o JSON serializado do campo stack de um PRD
        var converter = new StringListConverter();
        Map<String, Long> stackMap = new HashMap<>();
        for (String raw : prdRepository.findAllStacksRawByUser(userEmail)) {
            for (String item : converter.convertToEntityAttribute(raw)) {
                if (item != null && !item.isBlank()) {
                    stackMap.merge(item.trim(), 1L, (a, b) -> a + b);
                }
            }
        }
        List<PrdSummaryResponse.StackEntry> topStack = stackMap.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(6)
                .map(e -> new PrdSummaryResponse.StackEntry(e.getKey(), e.getValue()))
                .toList();

        // Atividade recente — row[3] pode ser Timestamp ou LocalDateTime dependendo do driver
        List<PrdSummaryResponse.RecentEntry> recent = prdRepository.findRecentByUser(userEmail, 5)
                .stream()
                .map(row -> new PrdSummaryResponse.RecentEntry(
                        UUID.fromString(String.valueOf(row[0])),
                        String.valueOf(row[1]),
                        String.valueOf(row[2]),
                        toInstant(row[3])))
                .toList();

        return new PrdSummaryResponse(total, byStatus, topStack, recent);
    }

    private static Instant toInstant(Object value) {
        if (value instanceof java.sql.Timestamp ts) return ts.toInstant();
        if (value instanceof java.time.LocalDateTime ldt) return ldt.toInstant(java.time.ZoneOffset.UTC);
        if (value instanceof Instant i) return i;
        throw new IllegalStateException("Tipo inesperado para updated_at: " + value.getClass());
    }

    // Remove apenas as entradas de cache do usuário afetado, preservando cache dos demais.
    // Fallback para cache.clear() garante comportamento correto se o provider mudar (ex.: Redis).
    private void evictUserCache(String userEmail) {
        var springCache = cacheManager.getCache("prds");
        if (springCache == null) return;
        if (springCache instanceof CaffeineCache caffeineCache) {
            Cache<Object, Object> nativeCache = caffeineCache.getNativeCache();
            nativeCache.asMap().keySet().removeIf(k -> k instanceof String s && s.startsWith(userEmail + "|"));
        } else {
            springCache.clear();
        }
    }
}
