package ng.prdgra.repository;

import ng.prdgra.model.Prd;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface PrdRepository extends JpaRepository<Prd, UUID> {

    @Query("SELECT p FROM Prd p WHERE p.user.email = :email AND p.deletedAt IS NULL ORDER BY p.updatedAt DESC")
    Page<Prd> findByUserEmail(@Param("email") String email, Pageable pageable);

    @Query("SELECT p FROM Prd p WHERE p.id = :id AND p.user.email = :email AND p.deletedAt IS NULL")
    Optional<Prd> findByIdAndUserEmail(@Param("id") UUID id, @Param("email") String email);
}
