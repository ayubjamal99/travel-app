package com.travelplanner.hello;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    private final HelloProperties properties;

    public HelloController(HelloProperties properties) {
        this.properties = properties;
    }

    @GetMapping("/api/v1/hello")
    public HelloResponse hello() {
        return new HelloResponse(properties.greeting());
    }
}
