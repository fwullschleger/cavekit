package frontier

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDeriveName(t *testing.T) {
	tests := []struct {
		filename string
		want     string
	}{
		{"build-site.md", "build-site"},           // no trailing dash, prefix doesn't match
		{"build-site-auth.md", "auth"},            // prefix "build-site-" stripped
		{"frontier-auth.md", "auth"},              // "-?frontier-?" strips "frontier-"
		{"plan-frontier-payments.md", "payments"}, // "plan-" prefix, then "frontier-"
		{"feature-frontend-frontier.md", "frontend"}, // "feature-" prefix, then "-frontier"
		{"frontier.md", "execute"},                // all stripped → empty → "execute"
		{"my-frontier-file.md", "myfile"},         // "-frontier-" removed, joins my+file
	}
	for _, tt := range tests {
		got := DeriveName(tt.filename)
		if got != tt.want {
			t.Errorf("DeriveName(%q) = %q, want %q", tt.filename, got, tt.want)
		}
	}
}

func TestDiscover(t *testing.T) {
	// Create temp project with frontier files
	tmp := t.TempDir()
	sitesDir := filepath.Join(tmp, "context", "sites")
	os.MkdirAll(sitesDir, 0755)
	os.MkdirAll(filepath.Join(sitesDir, "archive"), 0755)

	// Valid frontier files
	os.WriteFile(filepath.Join(sitesDir, "build-site.md"), []byte("# Frontier\n"), 0644)
	os.WriteFile(filepath.Join(sitesDir, "build-site-auth.md"), []byte("# Auth\n"), 0644)

	// Should be excluded (no frontier/site in name)
	os.WriteFile(filepath.Join(sitesDir, "readme.md"), []byte("# Readme\n"), 0644)

	// Archive file should be excluded (it's in a subdir)
	os.WriteFile(filepath.Join(sitesDir, "archive", "old-frontier.md"), []byte("old\n"), 0644)

	results, err := Discover(tmp)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("got %d results, want 2: %+v", len(results), results)
	}

	names := map[string]bool{}
	for _, r := range results {
		names[r.Name] = true
	}
	if !names["build-site"] {
		t.Errorf("expected 'build-site' in results, got %v", names)
	}
	if !names["auth"] {
		t.Errorf("expected 'auth' in results, got %v", names)
	}
}

func TestDiscover_EmptyDir(t *testing.T) {
	tmp := t.TempDir()
	results, err := Discover(tmp)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results for empty dir, got %d", len(results))
	}
}

func TestDiscover_LegacyFrontiersDir(t *testing.T) {
	tmp := t.TempDir()
	frontiersDir := filepath.Join(tmp, "context", "frontiers")
	os.MkdirAll(frontiersDir, 0755)
	os.WriteFile(filepath.Join(frontiersDir, "frontier-auth.md"), []byte("# Auth\n"), 0644)

	results, err := Discover(tmp)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("got %d results, want 1", len(results))
	}
	if results[0].Name != "auth" {
		t.Errorf("name = %q, want auth", results[0].Name)
	}
}
