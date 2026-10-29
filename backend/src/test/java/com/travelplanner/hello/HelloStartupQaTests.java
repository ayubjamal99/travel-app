package com.travelplanner.hello;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.travelplanner.BackendApplication;
import org.junit.jupiter.api.Test;
import org.springframework.boot.SpringApplication;

class HelloStartupQaTests {

    @Test
    void ac3_fullApplicationRefusesToStartWithoutGreetingAndNamesVariable() {
        assertThatThrownBy(() -> new SpringApplication(BackendApplication.class).run(
                "--spring.config.import=", "--server.port=0", "--hello.greeting="))
                .satisfies(t -> {
                    StringBuilder sb = new StringBuilder();
                    for (Throwable c = t; c != null; c = c.getCause()) sb.append(c.getMessage()).append('\n');
                    assertThat(sb.toString()).contains("HELLO_GREETING");
                });
    }
}
