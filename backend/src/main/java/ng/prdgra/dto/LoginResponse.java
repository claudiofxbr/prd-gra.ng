package ng.prdgra.dto;

public record LoginResponse(String token, String refreshToken, String name, String email, String role) {}
