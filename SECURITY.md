# Security Policy

## Supported Version

Security updates are applied to the current version of the `main` branch.

| Version | Supported |
|---|---|
| Current `main` branch | Yes |
| Older branches or commits | No |

## Reporting a Vulnerability

Do not publicly disclose a suspected vulnerability before it has been
reviewed.

To report a vulnerability:

1. Open the repository's **Security** tab.
2. Select **Report a vulnerability** when private reporting is available.
3. Identify the affected component.
4. Provide reproduction steps.
5. Explain the potential impact.
6. Include a suggested correction when possible.

If private reporting is unavailable, create a GitHub issue requesting a secure
contact method without publishing sensitive vulnerability details.

## Sensitive Information

Never commit or publish:

- Passwords
- API keys
- Access tokens
- Private keys
- Personally identifiable information
- Private student records
- Restricted datasets
- Environment files containing credentials

Secrets should be stored in environment variables or local files excluded by
`.gitignore`.

## Responsible Disclosure

Allow reasonable time for investigation and remediation before publicly
disclosing a confirmed vulnerability.

## Research Notice

This repository is intended for educational and research purposes. Model
outputs must not be treated as final decisions about individual students.
