ARG GO_IMAGE=wodby/go:1.26-dev

FROM $GO_IMAGE

COPY go.mod main.go .

RUN go build -o /home/wodby/go/bin/test-app .

CMD ["test-app"]
