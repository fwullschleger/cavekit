package tui

import (
	"fmt"
	"strings"

	"github.com/JuliusBrussee/cavekit/internal/site"
)

// SitePicker shows available sites for selection.
type SitePicker struct {
	items         []SitePickerItem
	selectedIndex int
	multiSelect   map[int]bool
	visible       bool
}

// SitePickerItem represents a selectable site.
type SitePickerItem struct {
	Name      string
	Path      string
	Status    site.SiteStatus
	TasksDone int
	TasksTotal int
}

// NewSitePicker creates a site picker.
func NewSitePicker() *SitePicker {
	return &SitePicker{
		multiSelect: make(map[int]bool),
	}
}

// SetItems populates the picker.
func (p *SitePicker) SetItems(items []SitePickerItem) {
	p.items = items
	p.selectedIndex = 0
	p.multiSelect = make(map[int]bool)
}

// Show makes the picker visible.
func (p *SitePicker) Show() {
	p.visible = true
}

// Hide hides the picker.
func (p *SitePicker) Hide() {
	p.visible = false
}

// IsVisible returns whether the picker is showing.
func (p *SitePicker) IsVisible() bool {
	return p.visible
}

// MoveDown moves selection down.
func (p *SitePicker) MoveDown() {
	if p.selectedIndex < len(p.items)-1 {
		p.selectedIndex++
	}
}

// MoveUp moves selection up.
func (p *SitePicker) MoveUp() {
	if p.selectedIndex > 0 {
		p.selectedIndex--
	}
}

// ToggleSelect toggles multi-select on current item.
func (p *SitePicker) ToggleSelect() {
	if p.selectedIndex < len(p.items) {
		item := p.items[p.selectedIndex]
		if item.Status == site.SiteDone {
			return // Can't select done sites
		}
		p.multiSelect[p.selectedIndex] = !p.multiSelect[p.selectedIndex]
	}
}

// SelectedItems returns the selected sites.
func (p *SitePicker) SelectedItems() []SitePickerItem {
	var result []SitePickerItem
	if len(p.multiSelect) == 0 {
		// Single select mode: return current
		if p.selectedIndex < len(p.items) {
			result = append(result, p.items[p.selectedIndex])
		}
		return result
	}
	for i, selected := range p.multiSelect {
		if selected && i < len(p.items) {
			result = append(result, p.items[i])
		}
	}
	return result
}

// View renders the picker.
func (p *SitePicker) View() string {
	if !p.visible || len(p.items) == 0 {
		return ""
	}

	var rows []string
	rows = append(rows, OverlayTitleStyle.Render("Select Site")+"\n")

	for i, item := range p.items {
		marker := "  "
		if p.multiSelect[i] {
			marker = "● "
		}
		if i == p.selectedIndex {
			marker = "→ "
		}

		status := item.Status.Icon()
		progress := fmt.Sprintf("%d/%d", item.TasksDone, item.TasksTotal)

		style := NormalItemStyle
		if item.Status == site.SiteDone {
			style = style.Strikethrough(true).Foreground(ColorMuted)
		}

		row := style.Render(fmt.Sprintf("%s%s %s %s", marker, status, item.Name, progress))
		rows = append(rows, row)
	}

	rows = append(rows, "\n"+MenuDescStyle.Render("Space to select · Enter to confirm · Esc to cancel"))
	return strings.Join(rows, "\n")
}
