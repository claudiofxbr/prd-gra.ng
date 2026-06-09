package ng.prdgra.repository;

import ng.prdgra.model.Prd;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PrdRepository extends JpaRepository<Prd, UUID> {

    @Query("SELECT p FROM Prd p WHERE p.user.email = :email AND p.deletedAt IS NULL ORDER BY p.updatedAt DESC")
    Page<Prd> findByUserEmail(@Param("email") String email, Pageable pageable);

    @Query("SELECT p FROM Prd p WHERE p.id = :id AND p.user.email = :email AND p.deletedAt IS NULL")
    Optional<Prd> findByIdAndUserEmail(@Param("id") UUID id, @Param("email") String email);

    @Query("SELECT p.status, COUNT(p) FROM Prd p WHERE p.user.email = :email AND p.deletedAt IS NULL GROUP BY p.status")
    List<Object[]> countByStatusForUser(@Param("email") String email);

    // Retorna o valor raw do campo stack (JSON serializado pelo StringListConverter)
    @Query(value = "SELECT p.stack FROM prds p JOIN users u ON p.user_id = u.id WHERE u.email = :email AND p.deleted_at IS NULL", nativeQuery = true)
    List<String> findAllStacksRawByUser(@Param("email") String email);

    @Query(value = "SELECT p.id::text, p.title, p.status, p.updated_at FROM prds p JOIN users u ON p.user_id = u.id WHERE u.email = :email AND p.deleted_at IS NULL ORDER BY p.updated_at DESC LIMIT :limit", nativeQuery = true)
    List<Object[]> findRecentByUser(@Param("email") String email, @Param("limit") int limit);
}
