package session

import (
	"path/filepath"

	"github.com/JuliusBrussee/cavekit/internal/site"
)

// UpdateProgress refreshes the progress fields on an instance
// by reading the site file and impl tracking files.
func UpdateProgress(inst *Instance) error {
	if inst.SitePath == "" {
		return nil
	}

	// Parse the site file
	f, err := site.Parse(inst.SitePath)
	if err != nil {
		return err
	}

	// Build impl directories to scan
	var implDirs []string
	if inst.WorktreePath != "" {
		implDirs = append(implDirs, filepath.Join(inst.WorktreePath, "context", "impl"))
	}

	// Track task statuses
	statuses, err := site.TrackStatus(implDirs...)
	if err != nil {
		return err
	}

	// Compute summary
	summary := site.ComputeProgress(f, statuses)
	inst.TasksDone = summary.Done
	inst.TasksTotal = summary.Total

	// Find current tier and task
	for _, task := range f.Tasks {
		status, exists := statuses[task.ID]
		if !exists || status == site.TaskPending {
			inst.CurrentTier = task.Tier
			inst.CurrentTask = task.ID
			break
		}
	}

	return nil
}
