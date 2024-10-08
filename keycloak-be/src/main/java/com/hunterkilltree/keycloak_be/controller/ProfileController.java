package com.hunterkilltree.keycloak_be.controller;

import java.util.List;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.hunterkilltree.keycloak_be.dto.ApiResponse;
import com.hunterkilltree.keycloak_be.dto.request.RegistrationRequest;
import com.hunterkilltree.keycloak_be.dto.request.UserLogin;
import com.hunterkilltree.keycloak_be.dto.response.AccessToken;
import com.hunterkilltree.keycloak_be.dto.response.ProfileResponse;
import com.hunterkilltree.keycloak_be.service.ProfileService;

import lombok.AccessLevel;
import lombok.RequiredArgsConstructor;
import lombok.experimental.FieldDefaults;
import lombok.extern.slf4j.Slf4j;

@RestController
@RequiredArgsConstructor
@FieldDefaults(level = AccessLevel.PRIVATE, makeFinal = true)
@Slf4j
public class ProfileController {
    ProfileService profileService;

    @PostMapping("/register")
    ApiResponse<ProfileResponse> register(@RequestBody @Valid RegistrationRequest request) {
        return ApiResponse.<ProfileResponse>builder()
                .result(profileService.register(request))
                .build();
    }

    // Deprecated
    @GetMapping("/login")
    public ApiResponse<AccessToken> login(@RequestBody UserLogin user) {
        return ApiResponse.<AccessToken>builder()
                .result(profileService.login(user))
                .build();
    }

    @GetMapping("/profiles")
    ApiResponse<List<ProfileResponse>> getAllProfiles() {
        return ApiResponse.<List<ProfileResponse>>builder()
                .result(profileService.getAllProfiles())
                .build();
    }

    @GetMapping("/my-profile")
    ApiResponse<ProfileResponse> getMyProfiles() {
        return ApiResponse.<ProfileResponse>builder()
                .result(profileService.getMyProfile())
                .build();
    }
}
