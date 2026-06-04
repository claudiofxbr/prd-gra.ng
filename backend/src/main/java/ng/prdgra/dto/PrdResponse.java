package ng.prdgra.dto;

import ng.prdgra.model.Prd;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PrdResponse(
        UUID id,
        String title,
        String description,
        List<String> stack,
        List<String> objectives,
        String status,
        Instant createdAt,
        Instant updatedAt
) {
    public static PrdResponse from(Prd prd) {
        return new PrdResponse(
                prd.getId(),
                prd.getTitle(),
                prd.getDescription(),
                prd.getStack(),
                prd.getObjectives(),
                prd.getStatus().name(),
                prd.getCreatedAt(),
                prd.getUpdatedAt()
        );
    }
}
