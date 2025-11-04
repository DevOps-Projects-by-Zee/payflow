# PayFlow - Production-Grade FinTech Platform

**Enterprise patterns for DevOps portfolios**

## 🎯 What You'll Build
- Hub-spoke VPC architecture ($175/month)
- Private EKS cluster with Multi-AZ HA
- Microservices application (6 services)
- Full observability stack (Prometheus, Grafana)
- CI/CD pipeline with GitOps

**Total Cost:** $180-250/month | **Time:** 3-4 hours | **Level:** Intermediate

## 🚀 Quick Start

**New here? Start with the learning path:**
1. [Start Here - 5 min read](docs/AWS/00-START-HERE.md)
2. [Prerequisites - 15 min setup](docs/AWS/01-PREREQUISITES.md)
3. [Understand Architecture - 30 min](docs/AWS/02-UNDERSTAND-FIRST.md)
4. [Deploy Infrastructure - 2 hours](docs/AWS/03-DEPLOY-HUB.md)

**Already know what you're doing?**
```bash
cd terraform/environments/hub && terraform apply
cd ../production && terraform apply
kubectl apply -k k8s/
```

## 📚 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Interview Prep](docs/INTERVIEW-GUIDE.md)
- [Local Deployment](docs/LOCAL/)

## 🎓 Learning Outcomes

After completing this project, you'll be able to:
- Explain hub-spoke VPC patterns in interviews ✅
- Deploy production-grade Kubernetes on AWS ✅
- Justify infrastructure cost decisions ✅
- Implement GitOps with ArgoCD ✅

## 💼 Interview Talking Points

This project demonstrates:
- Multi-AZ high availability patterns
- Cost optimization ($930/month → $250/month)
- Security defense-in-depth (7 layers)
- Infrastructure as Code best practices



## 📄 License

MIT License - Use this for your portfolio!
