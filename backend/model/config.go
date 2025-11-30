package model

// AppConfigResponse represents the app configuration
type AppConfigResponse struct {
	Maintenance    bool   `json:"maintenance"`
	MinimumVersion string `json:"minimumVersion"`
}
