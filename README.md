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
| CompTIA TECH+ (ITF+) | Earned |
| CompTIA A+ | Next target |
| CompTIA Network+ | Planned |
| CompTIA Security+ | Planned |
| CompTIA Linux+ | Planned |
| CompTIA CySA+ | Planned |
| CompTIA Pentest+ | Planned |

---

## Currently working on

- **NAS rebuild** — migrating TrueNAS to a 3-pool ZFS architecture (fast NVMe, bulk spinning, cold archive)
- **WGU coursework** — progressing through B.S. Cybersecurity, currently ~23% through the program
- **CompTIA A+ prep** — working through objectives, targeting exam in the near term
- **Homelab security hardening** — Wazuh SIEM rule tuning, detection coverage mapping to MITRE ATT&CK

---

## Homelab — Aegis AI Cluster

A production-grade 4-node homelab built for AI orchestration, security operations, and SRE practice.

| Node | Role | Specs |
|------|------|-------|
| **Jasper** | AI orchestrator, gaming/compute | i9-13900K, 64GB RAM, RTX 4090 |
| **Nova** | Proxmox primary hypervisor | — |
| **Mira** | Proxmox memory/analysis node | — |
| **Orin** | Proxmox heavy compute/isolation | — |

**Fabric:** 40GbE interconnect
**Storage:** TrueNAS with ZFS, multi-pool architecture
**Security:** OPNsense firewall, Wazuh SIEM
**Observability:** Prometheus + Grafana, burn-rate alerting, SLO tracking
**AI:** Distributed OpenClaw agent swarm, Pentagi AI pentesting platform, local LLM inference

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

### Reliability Pipeline (SRE)

SLO evaluation, burn-rate alerting, incident tracking, postmortem generation, and safety gates that block risky automation when reliability is degraded.

[Read case study](https://michealbreedlove.com/case-study-sre-pipeline.html)

### GitOps Backup System

Automated daily backups from 4 nodes with CI-enforced secret scanning (11 patterns), sanitization, and restore verification.

[Read case study](https://michealbreedlove.com/case-study-gitops-backups.html)

---

## Skills

**Languages:** Python, Bash, PowerShell
**Infrastructure:** Proxmox, ZFS, OPNsense, Linux
**Observability:** Prometheus, Grafana
**Security:** Wazuh SIEM, MITRE ATT&CK, secrets hygiene, least privilege
**Automation:** Docker, Git, GitHub Actions, systemd
**Practices:** SLOs, incident response, postmortems, GitOps

---

## Connect

- [Portfolio](https://michealbreedlove.com)
- [LinkedIn](https://www.linkedin.com/in/micheal-breedlove)
- [GitHub](https://github.com/MichealBreedlove)
- Email: mikejohnbreedlove@gmail.com
