# Micheal Breedlove

Security Engineering · DevSecOps · SRE · AI Infrastructure
Fairfield, CA (remote/hybrid)

![GitHub Stats](https://github-readme-stats.vercel.app/api?username=MichealBreedlove&show_icons=true&theme=dark&hide_border=true&count_private=true)
![Top Languages](https://github-readme-stats.vercel.app/api/top-langs/?username=MichealBreedlove&layout=compact&theme=dark&hide_border=true)

---

## Fastest proof

- **Architecture:** [AI Cluster - 4-node lab overview](https://michealbreedlove.com/ai-cluster.html)
- **Flagship work:** [Case studies (SRE pipeline, GitOps backups)](https://michealbreedlove.com/projects.html#flagship)
- **Proof Pack:** [Artifacts - dashboards, postmortems, configs, test reports](https://michealbreedlove.com/proof.html)
- **Resume:** [PDF](https://michealbreedlove.com/assets/Micheal-Breedlove-Resume.pdf)
- **Portfolio:** [michealbreedlove.com](https://michealbreedlove.com)

---

## Background

**U.S. Army Veteran — 35N Signals Intelligence Analyst**
Prior TS/SCI clearance with Counter-Terrorism polygraph (expired 2020). Spent years doing technical collection, signal analysis, and operational reporting in high-stakes SIGINT environments. That background shapes how I think about systems: adversarial assumptions, data integrity, need-to-know access, and operational security are defaults, not afterthoughts.

**B.S. Cybersecurity & Information Assurance** — WGU (in progress, ~23% complete)
**VA Disability:** 20% (service-connected)

---

## Certifications

| Cert | Status |
|------|--------|
| CompTIA TECH+ (ITF+) | ✅ Earned |
| CompTIA A+ | Next target |
| CompTIA Network+ | Planned |
| CompTIA Security+ | Planned |
| CompTIA Linux+ | Planned |
| CompTIA CySA+ | Planned |
| CompTIA Pentest+ | Planned |

---

## Currently working on

- **Network hardening** — completed VLAN segmentation across 10 VLANs, migrated DHCP to Kea, deployed UniFi U7-Pro-XG-B, firewall rule migration after OPNsense reinstall
- **WGU coursework** — progressing through B.S. Cybersecurity, currently ~23% through the program
- **CompTIA A+ prep** — working through objectives, targeting exam in the near term
- **Homelab security** — Wazuh SIEM tuning, Pentagi AI pentesting platform, MCP server for live cluster tooling in Claude

---

## Homelab — Aegis AI Cluster

A production-grade 4-node homelab built for AI orchestration, security operations, and SRE practice.

| Node | Role | Specs |
|------|------|-------|
| **Jasper** | AI orchestrator, gaming/compute | i9-13900K, 64GB RAM, RTX 4090 |
| **Nova** | Proxmox primary hypervisor | Intel N305, 32GB DDR5 |
| **Mira** | Proxmox memory/analysis node | i7-2600K, 16GB |
| **Orin** | Proxmox heavy compute/isolation | Dual Xeon E5-2667v4, 16GB ECC |

**Fabric:** 10GbE interconnect, VLAN-segmented (10 VLANs)
**Storage:** TrueNAS with ZFS, 3-pool architecture (fast/bulk/archive)
**Security:** OPNsense firewall, Wazuh SIEM, Pentagi AI pentesting
**Observability:** Prometheus + Grafana, burn-rate alerting, SLO tracking
**AI:** Distributed OpenClaw agent swarm, local LLM inference (Ollama/RTX 4090)
**MCP:** [aegis-cluster-mcp](https://github.com/MichealBreedlove/aegis-cluster-mcp) — native Claude tool access to every cluster layer

---

## What I build

Secure, reliable infrastructure and automation with measurable outcomes.

- Reliability engineering (SLOs, error budgets, burn-rate alerting)
- Infrastructure automation and GitOps pipelines
- Security-focused system design and detection engineering
- Incident response tooling and postmortem frameworks

---

## Featured work

### AI Cluster Architecture

Interactive architecture overview of the 4-node Aegis lab: GPU inference, Proxmox virtualization, SRE automation, and security boundaries.

[View architecture](https://michealbreedlove.com/ai-cluster.html)

### Aegis Cluster MCP

An MCP server giving Claude native tool access to every layer of the cluster — Proxmox, TrueNAS, OPNsense, Prometheus, and Wazuh. 20 tools. No copy-pasting API output.

[View repo](https://github.com/MichealBreedlove/aegis-cluster-mcp)

### Reliability Pipeline (SRE)

SLO evaluation, burn-rate alerting, incident tracking, postmortem generation, and safety gates that block risky automation when reliability is degraded.

[Read case study](https://michealbreedlove.com/case-study-sre-pipeline.html)

### GitOps Backup System

Automated daily backups from 4 nodes with CI-enforced secret scanning (11 patterns), sanitization, and restore verification.

[Read case study](https://michealbreedlove.com/case-study-gitops-backups.html)

---

## Skills

**Languages:** Python, Bash, PowerShell
**Infrastructure:** Proxmox, ZFS/TrueNAS, OPNsense, Linux, Ansible
**Observability:** Prometheus, Grafana, Wazuh SIEM
**Security:** MITRE ATT&CK, secrets hygiene, VLAN segmentation, least privilege
**Automation:** Docker, Git, GitHub Actions, systemd
**Practices:** SLOs, incident response, postmortems, GitOps

---

## Connect

- [Portfolio](https://michealbreedlove.com)
- [LinkedIn](https://www.linkedin.com/in/micheal-breedlove)
- [GitHub](https://github.com/MichealBreedlove)
- Email: mikejohnbreedlove@gmail.com
