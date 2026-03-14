---
name: Bridge Axiom
about: Document an assumption about external code behavior
title: "[BRIDGE] "
labels: bridge-axiom
assignees: ''

---

## Axiom

What external function/library are we trusting, and what property are we assuming?

### Module

Where will this axiom live? (e.g., `bridge/SWELibBridge/Syscalls/Socket.lean`)

### Lean Representation

```lean
-- TRUST: <this-issue-url>
axiom <name> : <property>
```

## Justification

Why do we believe this assumption is true?

### Evidence

- Documentation links
- Test results
- Audit reports
- Code references

## Audit Plan

How would we verify this assumption if questioned?

1. Step 1
2. Step 2
3. ...

## Related Issues

Link to any related spec or implementation issues.
