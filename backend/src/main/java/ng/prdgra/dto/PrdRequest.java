package ng.prdgra.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record PrdRequest(
        @NotBlank @Size(max = 255) String title,
        @Size(max = 5000) String description,
        @NotNull @Size(min = 1, max = 50, message = "stack deve ter entre 1 e 50 itens") List<@NotBlank @Size(max = 100) String> stack,
        @NotNull @Size(min = 1, max = 50, message = "objectives deve ter entre 1 e 50 itens") List<@NotBlank @Size(max = 500) String> objectives,
        String status
) {}
