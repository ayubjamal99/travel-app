package com.travelplanner.hello;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Bound from {@code hello.greeting}, which is fed by the HELLO_GREETING environment variable. */
@ConfigurationProperties(prefix = "hello")
public record HelloProperties(String greeting) {

    public HelloProperties {
        if (greeting == null || greeting.isBlank()) {
            throw new IllegalStateException(
                    "Missing required configuration: environment variable HELLO_GREETING must be set to a non-empty value");
        }
    }
}
