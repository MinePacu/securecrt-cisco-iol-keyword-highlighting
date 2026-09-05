# SecureCRT native matching probe

This is a diagnostic list, not a replacement for the production keyword list.
No native rendering result has been obtained yet. PCRE passing does not establish SecureCRT support.

1. Copy NAT-Matching-Probe.ini into the SecureCRT configuration's Keywords directory.
2. In the active test session's Session Options > Terminal > Keyword Highlighting,
   record the current keyword list and matching mode, then select NAT-Matching-Probe.
   Enable color highlighting and phrase/substring matching (Regex Line Mode=1).
3. Display fresh basic `show ip nat translations` output, including an ICMP row and a static `---` row.
   In configuration mode the user's existing `do sh ip nat t` command is suitable.
4. Capture both the output and the Keyword Highlighting settings. Restore the previous
   keyword list after collecting the result. Do not change router configuration.

| Target | Expected color if supported | What it tests |
| --- | --- | --- |
| Pro | red | Literal control; confirms the probe list is loaded |
| Inside global | gold | Multiword matching with escaped spaces |
| Inside (before local) | cyan | Forward lookahead |
| local (after Outside) | green | Fixed-width lookbehind into preceding text |
| Outside global | violet | Anchored consuming prefix plus keep-out, after prior matches |
| icmp | pink | Short regex control |
| :39829 or other :identifier | light sky blue | Substring matching inside an endpoint |
| --- | yellow | DEFINE and named subpattern call, independently of lookbehind |

If Pro is not red, do not infer regex incompatibility: first check the selected list,
color checkbox, mode, and whether fresh output was displayed. Other interpretations
are conditional on the red control passing. This separates basic syntax from the
previous 3,000-character composite patterns. Failure of the composite patterns alone
does not prove a length limit or identify which constituent failed.

Even if lookbehind passes here, combined DEFINE-in-lookbehind and production-list
priority still require separate tests before claiming column-specific NAT matching works.
