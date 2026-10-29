---
name: spring-boot
description: Backend conventions for the travel planner's Spring Boot (Java 21, Maven) service in backend/ — project layout, REST/API style, persistence, config, errors, tests. Use when creating or changing backend code.
---

# Spring Boot conventions

## Scaffold (first backend story only)
Generate from Spring Initializr so versions are current, then commit the wrapper:
```bash
curl -fsSL https://start.spring.io/starter.tgz \
  -d type=maven-project -d language=java -d javaVersion=21 \
  -d groupId=com.travelplanner -d artifactId=backend -d name=backend \
  -d packageName=com.travelplanner \
  -d dependencies=web,validation,actuator,data-jpa,postgresql,flyway,testcontainers \
  | tar -xzf - -C backend
```
Use the Maven wrapper (`./mvnw`) or `mvn -f backend/pom.xml`; CI uses `mvn -B -ntp -f backend/pom.xml verify`.

## Layout — package by feature
```
com.travelplanner
├── trips/        TripController, TripService, Trip (entity), TripRepository, dto/
├── itinerary/
├── common/       error handling, config, util
└── BackendApplication
```
No `controllers/ services/ repositories/` layer packages.

## API style
- REST under `/api/v1/**`, JSON, plural nouns: `GET /api/v1/trips/{id}`.
- Request/response DTOs are Java `record`s with Jakarta Validation annotations; never expose entities.
- Validate with `@Valid`; return `201 + Location` on create, `204` on delete.
- Errors: RFC 9457 problem details (`spring.mvc.problemdetails.enabled=true` + a
  `@RestControllerAdvice` mapping domain exceptions to `ProblemDetail`). No stack traces in responses.
- Health: Actuator `/actuator/health` is the liveness check.

## Code
- Constructor injection only (no field `@Autowired`); `final` fields.
- Services hold business logic and transactions (`@Transactional` on service methods).
- Use `java.time` types; store UTC.
- External APIs (LLM, flights, places…) behind an interface in the feature package
  (`ItineraryGenerator`), implementation reads its key from config; tests use a fake.
- Logging via SLF4J; never log secrets or full prompts containing user data.

## Persistence
- Flyway migrations in `src/main/resources/db/migration/V<n>__<desc>.sql`; never edit an applied one.
- `spring.jpa.hibernate.ddl-auto=validate`.

## Config
- `application.yml` with env-var placeholders: `${OPENAI_API_KEY:}` style, no real values.
- Load `.env` for local runs:
  `spring.config.import: optional:file:../.env[.properties],optional:file:.env[.properties]`
- Every new variable goes into `.env.example` with an empty value and a comment.

## Tests (see the testing skill)
- `@WebMvcTest` for controllers, plain JUnit for services, `@DataJpaTest` + Testcontainers Postgres
  for repositories, one `@SpringBootTest` smoke test per feature.
- Use `@ServiceConnection` with a `PostgreSQLContainer` for Testcontainers wiring.

## Local database (dev container)
- Docker runs on the host (docker-outside-of-docker). Containers you start are reached at
  `host.docker.internal`, not `localhost`.
- Add `compose.yaml` at the repo root with a `postgres:16-alpine` service on port 5432
  (user/db `travel`, password from `.env` as `POSTGRES_PASSWORD`).
- Local datasource: `jdbc:postgresql://${DB_HOST:host.docker.internal}:5432/travel`.
- Start it with `docker compose up -d db`; tests keep using Testcontainers.
