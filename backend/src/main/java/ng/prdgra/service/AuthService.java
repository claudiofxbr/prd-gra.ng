package ng.prdgra.service;

import lombok.RequiredArgsConstructor;
import ng.prdgra.dto.LoginRequest;
import ng.prdgra.dto.LoginResponse;
import ng.prdgra.dto.RegisterRequest;
import ng.prdgra.exception.EmailAlreadyRegisteredException;
import ng.prdgra.model.User;
import ng.prdgra.repository.UserRepository;
import ng.prdgra.security.JwtService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final RefreshTokenService refreshTokenService;

    @Transactional
    public LoginResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new EmailAlreadyRegisteredException();
        }
        var user = User.builder()
                .name(request.name())
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                .build();
        userRepository.save(user);
        var accessToken  = jwtService.generateToken(user.getEmail());
        var refreshToken = refreshTokenService.createToken(user);
        return new LoginResponse(accessToken, refreshToken, user.getName(), user.getEmail(), user.getRole());
    }

    @Transactional
    public LoginResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email(), request.password()));
        var user = userRepository.findByEmail(request.email()).orElseThrow();
        var accessToken  = jwtService.generateToken(user.getEmail());
        var refreshToken = refreshTokenService.createToken(user);
        return new LoginResponse(accessToken, refreshToken, user.getName(), user.getEmail(), user.getRole());
    }

    @Transactional
    public LoginResponse refresh(String plainRefreshToken) {
        var user         = refreshTokenService.validateAndRotate(plainRefreshToken);
        var accessToken  = jwtService.generateToken(user.getEmail());
        var newRefresh   = refreshTokenService.createToken(user);
        return new LoginResponse(accessToken, newRefresh, user.getName(), user.getEmail(), user.getRole());
    }

    @Transactional
    public void logout(String plainRefreshToken) {
        if (plainRefreshToken != null && !plainRefreshToken.isBlank()) {
            // Revoga todos os tokens sem validar atividade — logout deve funcionar
            // mesmo com token expirado ou já revogado.
            refreshTokenService.revokeAllByTokenHash(plainRefreshToken);
        }
    }
}
