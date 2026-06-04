package ng.prdgra.controller;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import ng.prdgra.config.CookieConstants;
import ng.prdgra.dto.LoginRequest;
import ng.prdgra.dto.RegisterRequest;
import ng.prdgra.dto.UserResponse;
import ng.prdgra.service.AuthService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.util.Arrays;
import java.util.Objects;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Value("${app.jwt.expiration-ms}")
    private long jwtExpirationMs;

    @Value("${app.refresh-token.expiration-days:30}")
    private int refreshExpirationDays;

    @PostMapping("/register")
    public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request,
                                                  HttpServletResponse response) {
        var result = authService.register(request);
        addAuthCookies(response, result.token(), result.refreshToken());
        return ResponseEntity.ok(new UserResponse(result.name(), result.email(), result.role()));
    }

    @PostMapping("/login")
    public ResponseEntity<UserResponse> login(@Valid @RequestBody LoginRequest request,
                                               HttpServletResponse response) {
        var result = authService.login(request);
        addAuthCookies(response, result.token(), result.refreshToken());
        return ResponseEntity.ok(new UserResponse(result.name(), result.email(), result.role()));
    }

    @PostMapping("/refresh")
    public ResponseEntity<UserResponse> refresh(HttpServletRequest request,
                                                 HttpServletResponse response) {
        String refreshToken = extractCookie(request, CookieConstants.REFRESH_TOKEN_COOKIE);
        if (refreshToken == null) {
            return ResponseEntity.status(401).build();
        }
        try {
            var result = authService.refresh(refreshToken);
            addAuthCookies(response, result.token(), result.refreshToken());
            return ResponseEntity.ok(new UserResponse(result.name(), result.email(), result.role()));
        } catch (IllegalArgumentException e) {
            clearAuthCookies(response);
            return ResponseEntity.status(401).build();
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpServletRequest request, HttpServletResponse response) {
        String refreshToken = extractCookie(request, CookieConstants.REFRESH_TOKEN_COOKIE);
        authService.logout(refreshToken);
        clearAuthCookies(response);
        return ResponseEntity.noContent().build();
    }

    private void addAuthCookies(HttpServletResponse response, String accessToken, String refreshToken) {
        Objects.requireNonNull(accessToken,  "accessToken must not be null");
        Objects.requireNonNull(refreshToken, "refreshToken must not be null");
        response.addHeader(HttpHeaders.SET_COOKIE,
                buildCookie(CookieConstants.TOKEN_COOKIE, accessToken,
                        Duration.ofMillis(jwtExpirationMs)).toString());
        response.addHeader(HttpHeaders.SET_COOKIE,
                buildCookie(CookieConstants.REFRESH_TOKEN_COOKIE, refreshToken,
                        Duration.ofDays(refreshExpirationDays)).toString());
    }

    private void clearAuthCookies(HttpServletResponse response) {
        response.addHeader(HttpHeaders.SET_COOKIE,
                buildCookie(CookieConstants.TOKEN_COOKIE, "", Duration.ZERO).toString());
        response.addHeader(HttpHeaders.SET_COOKIE,
                buildCookie(CookieConstants.REFRESH_TOKEN_COOKIE, "", Duration.ZERO).toString());
    }

    @SuppressWarnings("null")
    private ResponseCookie buildCookie(String name, String value, Duration maxAge) {
        return ResponseCookie.from(name, value)
                .httpOnly(true)
                .secure(true)
                .sameSite("Strict")
                .path("/")
                .maxAge(maxAge)
                .build();
    }

    @SuppressWarnings("unused")
    private String extractCookie(HttpServletRequest request, String name) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null) return null;
        return Arrays.stream(cookies)
                .filter(c -> name.equals(c.getName()))
                .map(Cookie::getValue)
                .findFirst()
                .orElse(null);
    }
}
