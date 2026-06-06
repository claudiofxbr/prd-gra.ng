package ng.prdgra.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import ng.prdgra.model.RefreshToken;
import ng.prdgra.model.User;
import ng.prdgra.repository.RefreshTokenRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;

@Service
@RequiredArgsConstructor
@Slf4j
public class RefreshTokenService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokenRepository;

    @Value("${app.refresh-token.expiration-days:30}")
    private int expirationDays;

    @Transactional
    public String createToken(User user) {
        // Gera 32 bytes aleatórios e armazena apenas o hash SHA-256 no banco
        byte[] raw = new byte[32];
        RANDOM.nextBytes(raw);
        String plainToken = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        String hash = sha256Hex(plainToken);

        RefreshToken entity = RefreshToken.builder()
                .user(user)
                .tokenHash(hash)
                .expiresAt(Instant.now().plusSeconds((long) expirationDays * 86_400))
                .build();
        // Salva o novo token ANTES de revogar os anteriores — garante que o usuário
        // nunca fique sem token válido se o save lançar exceção.
        @SuppressWarnings("null")
        RefreshToken saved = refreshTokenRepository.save(entity);
        assert saved != null;

        // Revoga todos os tokens anteriores, preservando o recém-criado.
        refreshTokenRepository.revokeAllByUserId(user.getId(), saved.getId());

        return plainToken;
    }

    @Transactional
    public User validateAndRotate(String plainToken) {
        String hash = sha256Hex(plainToken);
        RefreshToken rt = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new IllegalArgumentException("Refresh token inválido"));

        if (!rt.isActive()) {
            // Token expirado ou revogado — revogar todos os tokens do usuário (reuse detection)
            refreshTokenRepository.revokeAllByUserId(rt.getUser().getId());
            throw new IllegalArgumentException("Refresh token expirado ou revogado");
        }

        rt.setRevokedAt(Instant.now());
        refreshTokenRepository.save(rt);
        return rt.getUser();
    }

    @Transactional
    public void revokeAll(User user) {
        refreshTokenRepository.revokeAllByUserId(user.getId());
    }

    // Roda diariamente às 03:00 UTC — remove tokens expirados e revogados do banco.
    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    public void purgeExpiredTokens() {
        int deleted = refreshTokenRepository.deleteExpiredAndRevoked(Instant.now());
        if (deleted > 0) log.info("Refresh tokens purgados: {}", deleted);
    }

    private static String sha256Hex(String input) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(input.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 não disponível", e);
        }
    }
}
