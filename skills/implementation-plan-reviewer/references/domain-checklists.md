# Domain-Specific Gap Checklists

Use the checklist that matches the plan's domain in addition to the core framework.
Multiple checklists can apply (e.g., an ML pipeline deployed on cloud infra).

---

## 1. Machine Learning / AI Pipelines

**Data**
- [ ] Data source validated and accessible?
- [ ] Train/val/test split defined and reproducible?
- [ ] Data leakage between splits prevented?
- [ ] Class imbalance addressed?
- [ ] Missing value strategy defined?
- [ ] Feature drift handling in production?

**Training**
- [ ] Reproducibility: random seeds fixed?
- [ ] Experiment tracking (MLflow, W&B, etc.)?
- [ ] Hyperparameter tuning strategy defined?
- [ ] Compute requirements estimated?
- [ ] Training failure checkpointing?

**Evaluation**
- [ ] Evaluation metric aligned with business goal?
- [ ] Baseline comparison defined?
- [ ] Fairness / bias evaluation?
- [ ] Evaluation on held-out data (not val set)?

**Deployment**
- [ ] Model versioning strategy?
- [ ] Inference latency requirements defined?
- [ ] Model serving infrastructure specified?
- [ ] A/B testing or shadow mode before full rollout?
- [ ] Model monitoring (data drift, performance decay)?
- [ ] Retraining trigger defined?

**Agent-specific**
- [ ] Tool call failure handling?
- [ ] Infinite loop / recursion guard?
- [ ] Context window limits considered?
- [ ] Prompt injection risks addressed?
- [ ] Human-in-the-loop checkpoints for high-stakes decisions?

---

## 2. Web API / Backend Service

**Endpoints**
- [ ] All endpoints authenticated where required?
- [ ] Input validation on all user-supplied fields?
- [ ] Output sanitisation to prevent data leakage?
- [ ] Rate limiting implemented?
- [ ] Pagination for list endpoints?

**Database**
- [ ] Migrations versioned and reversible?
- [ ] Transactions used for multi-step writes?
- [ ] Index strategy for query performance?
- [ ] Connection pooling configured?
- [ ] Sensitive fields encrypted at rest?

**Error Handling**
- [ ] Consistent error response format?
- [ ] 4xx vs 5xx distinction clear?
- [ ] Errors logged with enough context to debug?
- [ ] Sensitive info excluded from error responses?

**Infrastructure**
- [ ] Environment variables for all config?
- [ ] Secrets managed (not hardcoded)?
- [ ] Health check endpoint exists?
- [ ] Graceful shutdown handled?
- [ ] Horizontal scaling considered?

**Testing**
- [ ] Unit tests for business logic?
- [ ] Integration tests for DB interactions?
- [ ] Contract tests for external APIs?
- [ ] Load/stress testing plan?

---

## 3. Data Pipeline / ETL

**Extraction**
- [ ] Source system access validated?
- [ ] Schema of source data documented?
- [ ] Incremental vs full-load strategy defined?
- [ ] Source system rate limits / quotas handled?

**Transformation**
- [ ] Data type casting handled explicitly?
- [ ] Null / missing value strategy per field?
- [ ] Deduplication logic defined?
- [ ] Business rule transformations documented and tested?
- [ ] Large dataset memory management?

**Loading**
- [ ] Target schema validated before load?
- [ ] Upsert vs insert strategy defined?
- [ ] Failed record handling (dead-letter queue)?
- [ ] Load idempotent (safe to rerun)?

**Orchestration**
- [ ] Retry logic on transient failures?
- [ ] DAG dependencies correctly modelled?
- [ ] SLA / freshness requirements defined?
- [ ] Backfill strategy for historical data?
- [ ] Alerting on pipeline failure?

---

## 4. Infrastructure / Cloud Deployment

**Provisioning**
- [ ] Infrastructure as Code (IaC) used?
- [ ] State management (e.g., Terraform state) handled?
- [ ] Resource tagging for cost tracking?
- [ ] Region / availability zone strategy?

**Networking**
- [ ] VPC / network segmentation defined?
- [ ] Security groups / firewall rules least-privilege?
- [ ] Ingress / egress rules documented?
- [ ] DNS and certificate management?

**Security**
- [ ] IAM roles follow least-privilege?
- [ ] Secrets stored in secrets manager (not env vars)?
- [ ] Encryption in transit (TLS) and at rest?
- [ ] Audit logging enabled?

**Reliability**
- [ ] Auto-scaling configured?
- [ ] Health checks and auto-restart?
- [ ] Multi-AZ or multi-region for critical services?
- [ ] Backup and restore tested?
- [ ] Disaster recovery plan documented?

**Observability**
- [ ] Centralised logging configured?
- [ ] Metrics and dashboards defined?
- [ ] Alerting thresholds set?
- [ ] On-call runbook exists?

---

## 5. Multi-Agent / Agentic Workflow

**Agent Design**
- [ ] Each agent's scope and responsibility clearly defined?
- [ ] Inter-agent communication protocol specified (message format, transport)?
- [ ] Agent handoff points explicitly modelled?
- [ ] Are there circular dependencies between agents?

**Reliability**
- [ ] What happens if an agent times out or crashes?
- [ ] Is there a supervisor / orchestrator to detect and recover?
- [ ] Are retries idempotent (safe to repeat)?
- [ ] Maximum retry limits defined?

**State Management**
- [ ] Shared state stored durably (not just in memory)?
- [ ] Concurrent writes to shared state handled (locking / CAS)?
- [ ] State schema versioned?

**Safety**
- [ ] Human approval gates for irreversible or high-stakes actions?
- [ ] Prompt injection from tool outputs guarded against?
- [ ] Scope limits enforced (agent cannot exceed authorised actions)?
- [ ] Audit trail of agent decisions stored?

**Testing**
- [ ] Individual agent unit tests?
- [ ] Integration tests for agent interactions?
- [ ] Chaos / fault injection tests?

---

## 6. Frontend / UI

**Correctness**
- [ ] All user flows covered in plan?
- [ ] Edge states handled (empty, error, loading)?
- [ ] Form validation (client-side + server-side)?

**Performance**
- [ ] Bundle size / code splitting considered?
- [ ] Images and assets optimised?
- [ ] Lazy loading for heavy components?

**Accessibility**
- [ ] ARIA labels and keyboard navigation?
- [ ] Colour contrast ratios met?
- [ ] Screen reader tested?

**Security**
- [ ] XSS prevention (sanitised outputs)?
- [ ] CSRF tokens for state-changing requests?
- [ ] Sensitive data not stored in localStorage?

**Testing**
- [ ] Component unit tests?
- [ ] E2E tests for critical user journeys?
- [ ] Cross-browser / cross-device coverage?
