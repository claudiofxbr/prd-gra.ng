package ng.prdgra.service;

import lombok.RequiredArgsConstructor;
import ng.prdgra.model.RefreshToken;
import ng.prdgra.model.User;
import ng.prdgra.repository.RefreshTokenRepository;
import org.springframework.beans.factory.annotation.Value;
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

        refreshTokenRepository.revokeAllByUserId(user.getId());

        RefreshToken entity = RefreshToken.builder()
                .user(user)
                .tokenHash(hash)
                .expiresAt(Instant.now().plusSeconds((long) expirationDays * 86_400))
                .build();
        @SuppressWarnings("null") // Spring Data save() nunca retorna null para entidades não-nulas
        var unused = refreshTokenRepository.save(entity);
        assert unused != null;

        return plainToken;
    }

    @Transactional
    public User validateAndRotate(String plainToken, String newAccessEmail) {
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
