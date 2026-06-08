package ng.prdgra.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import ng.prdgra.config.CookieConstants;
import ng.prdgra.repository.UserRepository;
import org.springframework.lang.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Arrays;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    // Endpoints públicos não precisam de token válido — o filtro os ignora completamente.
    // /auth/refresh é crítico: o access token pode estar expirado (é justamente o motivo do refresh),
    // então processar o cookie expirado resultaria em 401 antes de chegar ao AuthController.
    @Override
    protected boolean shouldNotFilter(@NonNull HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.equals("/auth/login")
            || path.equals("/auth/register")
            || path.equals("/auth/refresh")
            || path.equals("/auth/logout")
            || path.startsWith("/actuator/");
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        final String token = resolveToken(request);

        if (token == null) {
            filterChain.doFilter(request, response);
            return;
        }

        if (!jwtService.isValid(token)) {
            sendUnauthorized(response, "Token inválido ou expirado");
            return;
        }

        final String email = jwtService.extractEmail(token);

        if (email != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            var userOpt = userRepository.findByEmail(email);
            if (userOpt.isEmpty()) {
                log.warn("JWT válido mas usuário não encontrado (email omitido por segurança)");
                sendUnauthorized(response, "Usuário não encontrado");
                return;
            }
            var user = userOpt.get();
            var userDetails = org.springframework.security.core.userdetails.User.builder()
                    .username(user.getEmail())
                    .password(user.getPasswordHash())
                    .roles(user.getRole())
                    .build();
            var authToken = new UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.getAuthorities());
            authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(authToken);
        }

        filterChain.doFilter(request, response);
    }

    // Aceita token via cookie HttpOnly (browser) ou header Bearer (clientes API/mobile)
    private String resolveToken(HttpServletRequest request) {
        // 1. Cookie HttpOnly (preferencial — browser)
        Cookie[] cookies = request.getCookies();
        if (cookies != null) {
            return Arrays.stream(cookies)
                    .filter(c -> CookieConstants.TOKEN_COOKIE.equals(c.getName()))
                    .map(Cookie::getValue)
                    .findFirst()
                    .orElse(tryBearerHeader(request));
        }
        // 2. Fallback: Authorization: Bearer <token> (clientes não-browser)
        return tryBearerHeader(request);
    }

    private String tryBearerHeader(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }

    // Usa ObjectMapper para garantir JSON válido sem risco de injeção via message
    private void sendUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        String body = objectMapper.writeValueAsString(
                Map.of("status", 401, "detail", message));
        response.getWriter().write(body);
    }
}
