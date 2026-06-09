package ng.prdgra.dto;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public record PrdSummaryResponse(
        int total,
        Map<String, Long> byStatus,
        List<StackEntry> topStack,
        List<RecentEntry> recent
) {
    public record StackEntry(String name, long count) {}

    public record RecentEntry(UUID id, String title, String status, Instant updatedAt) {}
}
