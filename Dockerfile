FROM golang:1.13-alpine as build

WORKDIR /go/app

RUN set -ex \
  && apk add --no-cache git \
  && go get -tags "mysql" -u github.com/golang-migrate/migrate/cmd/migrate \
  && go get github.com/oxequa/realize

ENV GO111MODULE=on

COPY . .

RUN set -ex \
  && go build -o app

FROM alpine

WORKDIR /app

COPY --from=build /go/app/app .

RUN addgroup go \
  && adduser -D -G go go \
  && chown -R go:go /app/app

USER go

CMD ["./app"]
