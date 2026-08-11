# MDM and file-based fallback

**Owner:** Enterprise Platform / Governance Team
**Status:** Active
**Last verified:** 2026-08-09

---

## Precedence recap

```
1. MDM / device-management profile    (highest — overrides all)
2. Server managed settings            (this overlay)
3. File-based user config             (~/.config/github-copilot/settings.json)
4. User in-app preferences            (lowest)
```

---

## MDM fallback

MDM (Mobile Device Management) policy profiles are deployed via your MDM
solution (e.g. Jamf Pro, Microsoft Intune, Apple MDM). They operate at the
OS level and override any setting in this managed-settings overlay.

**When to use MDM:**
- Enforcing settings that must survive uninstall/reinstall of the Copilot CLI
- Settings that must apply before GitHub authentication (e.g. proxy config)
- Hard enforcement that users cannot bypass even if they delete the config file

**MDM profile keys** for GitHub Copilot CLI are documented at:
https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/configuring-github-copilot-in-the-cli

**Conflict resolution:** If an MDM profile and this managed-settings overlay
conflict, the MDM profile wins. For most enterprise environments, MDM should
set fewer settings (not duplicate managed-settings) to avoid confusion.

---

## File-based fallback

When the server managed settings cannot be reached (e.g. air-gapped
environments, during outages), Copilot clients fall back to the file-based
user config at:
- CLI/VS Code: `~/.config/github-copilot/settings.json`
- Windows: `%APPDATA%\GitHub\settings.json`

**Behavior during outage:**
- Clients use the last successfully applied server settings (cached).
- If no cache exists, clients fall back to file-based config.
- Security note: file-based config is user-writable and has lower precedence
  than server settings, so security-critical settings may be weakened during
  an extended outage if users modify their local file.

**Mitigation:** Use MDM to enforce the most critical security settings (e.g.
sandbox enforcement) independently of the server managed settings. This ensures
those settings persist during outages.

---

## Air-gapped environments

For environments without internet access to GitHub:
1. Configure a local GitHub Enterprise Server (GHES) instance.
2. Set the managed-settings source repository on GHES.
3. Ensure Copilot clients can reach the GHES instance.
4. Use MDM to enforce proxy/endpoint configuration.

GHES managed-settings support: verify with your GitHub account team for the
minimum GHES version that supports the managed-settings feature.
