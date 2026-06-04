package ng.prdgra.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import ng.prdgra.dto.PageResponse;
import ng.prdgra.dto.PrdRequest;
import ng.prdgra.dto.PrdResponse;
import ng.prdgra.service.PrdService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/prds")
@RequiredArgsConstructor
public class PrdController {

    private final PrdService prdService;

    @GetMapping
    public ResponseEntity<PageResponse<PrdResponse>> list(
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(prdService.listByUser(user.getUsername(), page, size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<PrdResponse> findById(@PathVariable UUID id,
                                                 @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(prdService.findById(id, user.getUsername()));
    }

    @PostMapping
    public ResponseEntity<PrdResponse> create(@Valid @RequestBody PrdRequest request,
                                               @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(prdService.create(request, user.getUsername()));
    }

    @PutMapping("/{id}")
    public ResponseEntity<PrdResponse> update(@PathVariable UUID id,
                                               @Valid @RequestBody PrdRequest request,
                                               @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(prdService.update(id, request, user.getUsername()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id,
                                        @AuthenticationPrincipal UserDetails user) {
        prdService.delete(id, user.getUsername());
        return ResponseEntity.noContent().build();
    }
}
