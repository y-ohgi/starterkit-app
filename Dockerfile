FROM golang:1.13-alpine as build

WORKDIR /go/app

ENV GO111MODULE=on

COPY . .

RUN apk add --no-cache git \
  && go build -o app \
  && go get -v gopkg.in/urfave/cli.v2@master && go get github.com/oxequa/realize

FROM alpine

WORKDIR /app

COPY --from=build /go/app/app .

RUN addgroup go \
  && adduser -D -G go go \
  && chown -R go:go /app/app

USER go

CMD ["./app"]
