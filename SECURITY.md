# Security policy

The current 0.4.x preview is the supported line. Older private prototypes are not distributed or supported by this repository.

Report vulnerabilities privately using [GitHub Security Advisories](https://github.com/xyizhan/flow-translate/security/advisories/new). Do not open a public issue containing a working exploit against another service, API credentials, private documents, passwords, or unredacted logs. Describe the affected version, expected versus observed behavior, and a minimal reproduction with generated sample text and dummy credentials.

Release artifacts have SHA-256 checksums and an ad-hoc code signature. They are **not Developer ID signed or Apple-notarized**. Checksums establish integrity relative to the release manifest; they do not replace developer identification or an independent security audit. The repository is scanned for known credential patterns and local paths, but no scanner can prove the absence of every security issue.

API requests require HTTPS except on loopback hosts, do not follow redirects, and do not persist URLSession caches. Keys stay in Keychain and are not logged. Sensitive text should only be sent to providers the user explicitly trusts. Local learning files have restrictive file permissions but are not encrypted.

请通过上方私密入口报告安全问题，不要在公开 Issue 中粘贴真实 API Key、系统密码、私人文档或未脱敏日志。本项目不要求关闭 Gatekeeper / SIP，也不要求把系统密码发送给维护者。
