package ng.prdgra.controller;

import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.NoSuchElementException;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Dados inválidos");
        detail.setDetail(ex.getBindingResult().getFieldErrors().stream()
                .map(e -> e.getField() + ": " + e.getDefaultMessage())
                .reduce((a, b) -> a + "; " + b).orElse("Entrada inválida"));
        return detail;
    }

    // Violações de @Min/@Max/@NotBlank em @RequestParam (via @Validated no controller)
    @ExceptionHandler(ConstraintViolationException.class)
    public ProblemDetail handleConstraintViolation(ConstraintViolationException ex) {
        String msg = ex.getConstraintViolations().stream()
                .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                .reduce((a, b) -> a + "; " + b).orElse("Parâmetro inválido");
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setTitle("Parâmetro inválido");
        detail.setDetail(msg);
        return detail;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleIllegalArgument(IllegalArgumentException ex) {
        // E-mail já registrado é conflito (409), não erro de validação (400)
        if (ex.getMessage() != null && ex.getMessage().contains("already registered")) {
            var detail = ProblemDetail.forStatus(HttpStatus.CONFLICT);
            detail.setDetail(ex.getMessage());
            return detail;
        }
        var detail = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        detail.setDetail(ex.getMessage());
        return detail;
    }

    @ExceptionHandler(NoSuchElementException.class)
    public ProblemDetail handleNotFound(NoSuchElementException ex) {
        var detail = ProblemDetail.forStatus(HttpStatus.NOT_FOUND);
        detail.setDetail(ex.getMessage());
        return detail;
    }

    // Violação de constraint do BD (UK, FK, NOT NULL) — ex.: e-mail duplicado em race condition
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ProblemDetail handleDataIntegrity(DataIntegrityViolationException ex) {
        log.warn("Violação de integridade de dados: {}", ex.getMostSpecificCause().getMessage());
        var detail = ProblemDetail.forStatus(HttpStatus.CONFLICT);
        detail.setDetail("Operação viola restrição de integridade de dados.");
        return detail;
    }

    // Nunca revelar se o e-mail existe ou não — resposta genérica para ambos os casos
    @ExceptionHandler({UsernameNotFoundException.class, BadCredentialsException.class})
    public ProblemDetail handleAuthFailure(RuntimeException ex) {
        log.debug("Falha de autenticação: {}", ex.getMessage());
        var detail = ProblemDetail.forStatus(HttpStatus.UNAUTHORIZED);
        detail.setDetail("E-mail ou senha inválidos");
        return detail;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Erro inesperado", ex);
        var detail = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        detail.setDetail("Ocorreu um erro interno. Tente novamente.");
        return detail;
    }
}
