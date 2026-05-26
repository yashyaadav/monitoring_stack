# syntax=docker/dockerfile:1.7

FROM golang:1.22-alpine AS build
WORKDIR /src
RUN apk add --no-cache git
COPY go.mod ./
COPY go.su[m] ./
COPY . .
RUN go mod tidy
ARG APP_VERSION=v1.0.0
ARG APP_COMMIT=unknown
ENV CGO_ENABLED=0 GOOS=linux GOARCH=amd64
RUN go build \
      -ldflags="-s -w -X main.version=${APP_VERSION} -X main.commit=${APP_COMMIT}" \
      -o /out/sample-app .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/sample-app /sample-app
USER nonroot:nonroot
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/sample-app", "healthcheck"]
ENTRYPOINT ["/sample-app"]
