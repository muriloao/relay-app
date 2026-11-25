package protocol

import "encoding/json"

type Message struct {
	Type string `json:"type"`
	ID string `json:"id,omitempty"`
	Token string `json:"token,omitempty"`
	Action string `json:"action,omitempty"`
	Value *float64 `json:"value,omitempty"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type Response struct {
	Type string `json:"type"`
	ID string `json:"id,omitempty"`
	OK bool `json:"ok,omitempty"`
	Error string `json:"error,omitempty"`
	MachineName string `json:"machine_name,omitempty"`
	Capabilities []string `json:"capabilities,omitempty"`
	Payload any `json:"payload,omitempty"`
}

type PairingInfo struct {
	IP string `json:"ip"`
	Port int `json:"port"`
	MAC string `json:"mac"`
	Token string `json:"token"`
	Name string `json:"name"`
}
