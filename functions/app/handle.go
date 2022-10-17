package function

import (
	"context"
	"io/ioutil"
	"net/http"
)

// Handle an HTTP Request.
func Handle(ctx context.Context, res http.ResponseWriter, req *http.Request) {
	/*
	 * YOUR CODE HERE
	 *
	 * Try running `go test`.  Add more test as you code in `handle_test.go`.
	 */

	fileBytes, err := ioutil.ReadFile("rainbow.png")
	if err != nil {
		panic(err)
	}
	res.WriteHeader(http.StatusOK)
	res.Header().Set("Content-Type", "application/octet-stream")
	res.Write(fileBytes)

}
