package ng.prdgra;

import ng.prdgra.dto.LoginRequest;
import ng.prdgra.dto.RegisterRequest;
import ng.prdgra.exception.EmailAlreadyRegisteredException;
import ng.prdgra.model.User;
import ng.prdgra.repository.UserRepository;
import ng.prdgra.security.JwtService;
import ng.prdgra.service.AuthService;
import ng.prdgra.service.RefreshTokenService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock AuthenticationManager authenticationManager;
    @Mock RefreshTokenService refreshTokenService;

    @InjectMocks AuthService authService;

    private User sampleUser;

    @BeforeEach
    void setUp() {
        sampleUser = User.builder()
                .id(UUID.randomUUID())
                .name("Test User")
                .email("test@example.com")
                .passwordHash("hashed")
                .build();
    }

    @Test
    void register_newEmail_returnsTokens() {
        when(userRepository.existsByEmail("test@example.com")).thenReturn(false);
        when(passwordEncoder.encode(anyString())).thenReturn("hashed");
        when(userRepository.save(any(User.class))).thenReturn(sampleUser);
        when(jwtService.generateToken("test@example.com")).thenReturn("access-token");
        when(refreshTokenService.createToken(any())).thenReturn("refresh-token");

        var result = authService.register(new RegisterRequest("Test User", "test@example.com", "password123"));

        assertThat(result.token()).isEqualTo("access-token");
        assertThat(result.refreshToken()).isEqualTo("refresh-token");
        assertThat(result.email()).isEqualTo("test@example.com");
    }

    @Test
    void register_duplicateEmail_throwsIllegalArgument() {
        when(userRepository.existsByEmail("test@example.com")).thenReturn(true);

        assertThatThrownBy(() ->
                authService.register(new RegisterRequest("Test", "test@example.com", "password123")))
                .isInstanceOf(EmailAlreadyRegisteredException.class);

        verify(userRepository, never()).save(any());
    }

    @Test
    void login_validCredentials_returnsTokens() {
        when(userRepository.findByEmail("test@example.com")).thenReturn(Optional.of(sampleUser));
        when(jwtService.generateToken("test@example.com")).thenReturn("access-token");
        when(refreshTokenService.createToken(any())).thenReturn("refresh-token");

        var result = authService.login(new LoginRequest("test@example.com", "password123"));

        verify(authenticationManager).authenticate(any(UsernamePasswordAuthenticationToken.class));
        assertThat(result.token()).isEqualTo("access-token");
    }

    @Test
    void refresh_validToken_rotatesAndReturnsNewTokens() {
        when(refreshTokenService.validateAndRotate("old-refresh")).thenReturn(sampleUser);
        when(jwtService.generateToken("test@example.com")).thenReturn("new-access");
        when(refreshTokenService.createToken(sampleUser)).thenReturn("new-refresh");

        var result = authService.refresh("old-refresh");

        assertThat(result.token()).isEqualTo("new-access");
        assertThat(result.refreshToken()).isEqualTo("new-refresh");
    }

    @Test
    void logout_withValidToken_revokesAllTokens() {
        authService.logout("some-refresh-token");

        verify(refreshTokenService).revokeAllByTokenHash("some-refresh-token");
        verify(refreshTokenService, never()).validateAndRotate(anyString());
    }

    @Test
    void logout_withExpiredToken_stillRevokesTokens() {
        // Mesmo com token expirado/inválido, revokeAllByTokenHash é chamado
        // (o método internamente faz ifPresent — não lança exceção)
        doNothing().when(refreshTokenService).revokeAllByTokenHash(anyString());

        authService.logout("expired-token");

        verify(refreshTokenService).revokeAllByTokenHash("expired-token");
    }

    @Test
    void logout_nullToken_doesNothing() {
        authService.logout(null);
        verifyNoInteractions(refreshTokenService);
    }

    @Test
    void logout_blankToken_doesNothing() {
        authService.logout("   ");
        verifyNoInteractions(refreshTokenService);
    }
}
