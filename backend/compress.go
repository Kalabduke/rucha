package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"errors"
	"io"
)

const compressionMarker = "gzip"

func packPayload(v interface{}) ([]byte, []byte, int, error) {
	raw, err := json.Marshal(v)
	if err != nil {
		return nil, nil, 0, err
	}
	var buf bytes.Buffer
	w, err := gzip.NewWriterLevel(&buf, gzip.DefaultCompression)
	if err != nil {
		return nil, nil, 0, err
	}
	if _, err = w.Write(raw); err != nil {
		w.Close()
		return nil, nil, 0, err
	}
	if err = w.Close(); err != nil {
		return nil, nil, 0, err
	}
	index, err := json.Marshal(map[string]string{"c": compressionMarker})
	if err != nil {
		return nil, nil, 0, err
	}
	return index, buf.Bytes(), len(raw), nil
}

func unpackPayload(raw, gz []byte, v interface{}) error {
	if len(gz) > 0 {
		r, err := gzip.NewReader(bytes.NewReader(gz))
		if err != nil {
			return err
		}
		defer r.Close()
		plain, err := io.ReadAll(io.LimitReader(r, 32<<20))
		if err != nil {
			return err
		}
		return json.Unmarshal(plain, v)
	}
	if len(raw) == 0 {
		return errors.New("empty row payload")
	}
	return json.Unmarshal(raw, v)
}
