// Package frontier handles frontier file discovery, parsing, and task tracking.
package frontier

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// DeriveName applies the canonical name derivation from a frontier filename.
// Mirrors the bash sed chain: strip prefixes (plan-, build-site-, feature-),
// strip -?frontier-?, strip leading/trailing hyphens. Empty → "execute".
func DeriveName(filename string) string {
	// Strip extension
	name := strings.TrimSuffix(filename, filepath.Ext(filename))

	// Strip known prefixes
	for _, prefix := range []string{"plan-", "build-site-", "feature-"} {
		name = strings.TrimPrefix(name, prefix)
	}

	// Strip frontier with optional surrounding hyphens
	re := regexp.MustCompile(`-?frontier-?`)
	name = re.ReplaceAllString(name, "")

	// Strip leading/trailing hyphens
	name = strings.Trim(name, "-")

	if name == "" {
		return "execute"
	}
	return name
}

// FrontierFile represents a discovered frontier file.
type FrontierFile struct {
	Path string // Full path to the file
	Name string // Derived name (used for worktree/branch naming)
}

// Discover scans context/sites/ (or context/frontiers/) for frontier markdown files.
// Excludes archive/ subdirectory.
func Discover(projectRoot string) ([]FrontierFile, error) {
	var results []FrontierFile

	// Try both directory names (sites is the newer convention, frontiers is legacy)
	for _, dir := range []string{"context/sites", "context/frontiers"} {
		frontierDir := filepath.Join(projectRoot, dir)
		entries, err := os.ReadDir(frontierDir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, err
		}

		for _, entry := range entries {
			if entry.IsDir() {
				continue // skip archive/ and other subdirs
			}
			name := entry.Name()
			if !strings.HasSuffix(name, ".md") {
				continue
			}
			// File must contain "frontier" or "site" in the name (broad match)
			lowerName := strings.ToLower(name)
			if !strings.Contains(lowerName, "frontier") && !strings.Contains(lowerName, "site") {
				continue
			}

			results = append(results, FrontierFile{
				Path: filepath.Join(frontierDir, name),
				Name: DeriveName(name),
			})
		}
	}

	return results, nil
}
