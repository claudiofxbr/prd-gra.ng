package ng.prdgra.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Component
@RequiredArgsConstructor
@Slf4j
public class RateLimitFilter extends OncePerRequestFilter {

    private static final int  MAX_REQUESTS = 10;
    private static final long WINDOW_MS    = 60_000L;

    // IP confiável do proxy reverso — apenas este pode setar X-Forwarded-For
    private static final String TRUSTED_PROXY = "127.0.0.1";

    private final ObjectMapper objectMapper;
    private final ConcurrentHashMap<String, WindowEntry> windows = new ConcurrentHashMap<>();

    @Override
    protected boolean shouldNotFilter(@NonNull HttpServletRequest request) {
        String path = request.getRequestURI();
        return !path.contains("/auth/login") && !path.contains("/auth/register");
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        String ip = resolveClientIp(request);

        WindowEntry entry = windows.compute(ip, (k, existing) -> {
            long now = System.currentTimeMillis();
            if (existing == null || now - existing.windowStart > WINDOW_MS) {
                return new WindowEntry(now, new AtomicInteger(1));
            }
            existing.count.incrementAndGet();
            return existing;
        });

        if (entry.count.get() > MAX_REQUESTS) {
            log.warn("Rate limit atingido para IP: {}", ip);
            sendTooManyRequests(response);
            return;
        }

        filterChain.doFilter(request, response);
    }

    // X-Forwarded-For só é aceito se a requisição vier do proxy reverso confiável,
    // evitando que atacantes forjem IPs para bypass do rate limit.
    private String resolveClientIp(HttpServletRequest request) {
        String remoteAddr = request.getRemoteAddr();
        if (TRUSTED_PROXY.equals(remoteAddr)) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                return forwarded.split(",")[0].trim();
            }
        }
        return remoteAddr;
    }

    // Remove entradas de janelas expiradas para evitar crescimento ilimitado do mapa.
    // Roda a cada 5 minutos — janela de 1 min garante que entradas com 5+ min são seguras para remover.
    @Scheduled(fixedDelay = 300_000L)
    public void evictExpiredWindows() {
        long now = System.currentTimeMillis();
        int removed = 0;
        for (var it = windows.entrySet().iterator(); it.hasNext(); ) {
            if (now - it.next().getValue().windowStart > WINDOW_MS * 5) {
                it.remove();
                removed++;
            }
        }
        if (removed > 0) log.debug("Rate limit: {} entradas expiradas removidas", removed);
    }

    private void sendTooManyRequests(HttpServletResponse response) throws IOException {
        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        String body = objectMapper.writeValueAsString(
                Map.of("status", 429, "detail", "Muitas tentativas. Aguarde um minuto e tente novamente."));
        response.getWriter().write(body);
    }

    private record WindowEntry(long windowStart, AtomicInteger count) {}
}
