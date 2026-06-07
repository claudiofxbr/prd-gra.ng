package ng.prdgra.service;

import com.github.benmanes.caffeine.cache.Cache;
import lombok.RequiredArgsConstructor;
import ng.prdgra.dto.PageResponse;
import ng.prdgra.dto.PrdRequest;
import ng.prdgra.dto.PrdResponse;
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
import java.util.NoSuchElementException;
import java.util.Objects;
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
        // getReferenceById evita SELECT extra — apenas o FK é necessário para auditoria
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
        @SuppressWarnings("null")
        Prd saved = Objects.requireNonNull(prdRepository.save(prd), "save retornou null");
        evictUserCache(userEmail);
        return PrdResponse.from(saved);
    }

    @Transactional
    public PrdResponse update(UUID id, PrdRequest request, String userEmail) {
        User userRef = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new UsernameNotFoundException(userEmail));
        var prd = prdRepository.findByIdAndUserEmail(id, userEmail)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
        prd.setTitle(request.title());
        prd.setDescription(request.description());
        prd.setStack(request.stack());
        prd.setObjectives(request.objectives());
        prd.setModifiedBy(userRef);
        if (request.status() != null) {
            try {
                prd.setStatus(Prd.PrdStatus.valueOf(request.status()));
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("Status inválido: " + request.status());
            }
        }
        @SuppressWarnings("null")
        Prd saved = Objects.requireNonNull(prdRepository.save(prd), "save retornou null");
        evictUserCache(userEmail);
        return PrdResponse.from(saved);
    }

    @Transactional
    public void delete(UUID id, String userEmail) {
        User userRef = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new UsernameNotFoundException(userEmail));
        var prd = prdRepository.findByIdAndUserEmail(id, userEmail)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
        prd.setDeletedAt(Instant.now());
        prd.setDeletedBy(userRef);
        prdRepository.save(prd);
        evictUserCache(userEmail);
    }

    public PrdResponse findById(UUID id, String userEmail) {
        return prdRepository.findByIdAndUserEmail(id, userEmail)
                .map(PrdResponse::from)
                .orElseThrow(() -> new NoSuchElementException("PRD não encontrado"));
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
