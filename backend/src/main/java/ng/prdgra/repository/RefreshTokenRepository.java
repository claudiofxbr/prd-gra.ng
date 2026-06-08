package ng.prdgra.repository;

import ng.prdgra.model.RefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    // Usado no logout: busca sem validar atividade para revogar mesmo tokens já expirados
    @Query("SELECT r.user FROM RefreshToken r WHERE r.tokenHash = :hash")
    Optional<ng.prdgra.model.User> findUserByTokenHash(@Param("hash") String hash);

    @Modifying
    @Transactional
    @Query("UPDATE RefreshToken r SET r.revokedAt = CURRENT_TIMESTAMP WHERE r.user.id = :userId AND r.revokedAt IS NULL")
    void revokeAllByUserId(@Param("userId") UUID userId);

    @Modifying
    @Transactional
    @Query("UPDATE RefreshToken r SET r.revokedAt = CURRENT_TIMESTAMP WHERE r.user.id = :userId AND r.id <> :excludeId AND r.revokedAt IS NULL")
    void revokeAllByUserId(@Param("userId") UUID userId, @Param("excludeId") UUID excludeId);

    @Modifying
    @Transactional
    @Query("DELETE FROM RefreshToken r WHERE r.expiresAt < :cutoff OR r.revokedAt IS NOT NULL")
    int deleteExpiredAndRevoked(@Param("cutoff") Instant cutoff);
}
