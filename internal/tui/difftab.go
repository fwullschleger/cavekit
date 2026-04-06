package tui

import (
	"context"
	"fmt"
	"strings"

	"github.com/JuliusBrussee/cavekit/internal/worktree"
)

// DiffTab renders git diff output for the selected instance.
type DiffTab struct {
	wtMgr          *worktree.Manager
	rawDiff        string
	stats          worktree.DiffStats
	scrollPos      int
	fileBoundaries []int // line indices of "diff --git" headers
}

// NewDiffTab creates a diff tab.
func NewDiffTab(wtMgr *worktree.Manager) *DiffTab {
	return &DiffTab{wtMgr: wtMgr}
}

// Refresh updates the diff content for the given worktree.
func (d *DiffTab) Refresh(ctx context.Context, wtPath string) {
	if wtPath == "" {
		d.rawDiff = ""
		d.stats = worktree.DiffStats{}
		d.fileBoundaries = nil
		return
	}

	stats, err := d.wtMgr.DiffStat(ctx, wtPath)
	if err == nil {
		d.stats = stats
	}

	diff, err := d.wtMgr.Diff(ctx, wtPath)
	if err == nil {
		d.rawDiff = diff
		d.parseFileBoundaries()
	}
}

// Stats returns the current diff stats string (e.g. "+45/-12").
func (d *DiffTab) Stats() string {
	if d.stats.Insertions == 0 && d.stats.Deletions == 0 {
		return ""
	}
	return fmt.Sprintf("+%d/-%d", d.stats.Insertions, d.stats.Deletions)
}

// Content returns the styled diff output.
func (d *DiffTab) Content() string {
	if d.rawDiff == "" {
		return ""
	}

	header := DiffHeaderStyle.Render(d.stats.String()) + "\n\n"

	lines := strings.Split(d.rawDiff, "\n")
	var styled []string
	lineNum := 0
	var currentFile string

	for _, line := range lines {
		switch {
		case strings.HasPrefix(line, "diff --git"):
			// Extract filename
			parts := strings.SplitN(line, " b/", 2)
			if len(parts) == 2 {
				currentFile = parts[1]
			}
			styled = append(styled, "")
			styled = append(styled, DiffFileSectionStyle.Render("  "+currentFile))
			styled = append(styled, "")
			lineNum = 0

		case strings.HasPrefix(line, "@@"):
			// Parse hunk header for line number
			lineNum = parseHunkLineNum(line)
			styled = append(styled, DiffHeaderStyle.Render(line))

		case strings.HasPrefix(line, "+") && !strings.HasPrefix(line, "+++"):
			numStr := DiffLineNumberStyle.Render(fmt.Sprintf("%4d", lineNum))
			styled = append(styled, numStr+" "+DiffAddStyle.Render(line))
			lineNum++

		case strings.HasPrefix(line, "-") && !strings.HasPrefix(line, "---"):
			numStr := DiffLineNumberStyle.Render("    ")
			styled = append(styled, numStr+" "+DiffRemoveStyle.Render(line))

		case strings.HasPrefix(line, "---") || strings.HasPrefix(line, "+++"):
			// Skip file header lines (already shown as section header)
			continue

		case strings.HasPrefix(line, "index ") || strings.HasPrefix(line, "new file") || strings.HasPrefix(line, "deleted file"):
			continue

		default:
			if lineNum > 0 {
				numStr := DiffLineNumberStyle.Render(fmt.Sprintf("%4d", lineNum))
				styled = append(styled, numStr+" "+line)
				lineNum++
			} else {
				styled = append(styled, line)
			}
		}
	}

	// Apply scroll position
	if d.scrollPos > 0 && d.scrollPos < len(styled) {
		styled = styled[d.scrollPos:]
	} else if d.scrollPos >= len(styled) {
		d.scrollPos = max(0, len(styled)-1)
		if len(styled) > 0 {
			styled = styled[len(styled)-1:]
		}
	}

	_ = currentFile
	return header + strings.Join(styled, "\n")
}

// ScrollDown moves the scroll position down.
func (d *DiffTab) ScrollDown(n int) {
	d.scrollPos += n
}

// ScrollUp moves the scroll position up.
func (d *DiffTab) ScrollUp(n int) {
	d.scrollPos -= n
	if d.scrollPos < 0 {
		d.scrollPos = 0
	}
}

// NextFile jumps to the next file boundary.
func (d *DiffTab) NextFile() {
	for _, boundary := range d.fileBoundaries {
		if boundary > d.scrollPos {
			d.scrollPos = boundary
			return
		}
	}
}

// PrevFile jumps to the previous file boundary.
func (d *DiffTab) PrevFile() {
	for i := len(d.fileBoundaries) - 1; i >= 0; i-- {
		if d.fileBoundaries[i] < d.scrollPos {
			d.scrollPos = d.fileBoundaries[i]
			return
		}
	}
	d.scrollPos = 0
}

func (d *DiffTab) parseFileBoundaries() {
	d.fileBoundaries = nil
	lineIdx := 0
	for _, line := range strings.Split(d.rawDiff, "\n") {
		if strings.HasPrefix(line, "diff --git") {
			d.fileBoundaries = append(d.fileBoundaries, lineIdx)
		}
		lineIdx++
	}
}

// parseHunkLineNum extracts the starting line number from a @@ hunk header.
func parseHunkLineNum(line string) int {
	// Format: @@ -a,b +c,d @@
	idx := strings.Index(line, "+")
	if idx < 0 {
		return 0
	}
	rest := line[idx+1:]
	num := 0
	for _, c := range rest {
		if c >= '0' && c <= '9' {
			num = num*10 + int(c-'0')
		} else {
			break
		}
	}
	return num
}
