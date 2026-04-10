# 🚀 Salesforce Developer Toolkit

A secure, in-org developer toolkit built with **Lightning Web Components (LWC)** and **Apex** to simplify how Salesforce developers interact with data, metadata, and APIs — without relying on third-party browser extensions.

---

## ⚠️ Why this project?

In many organizations, tools like Salesforce Inspector are being restricted or completely removed due to **third-party security concerns**.

This project solves that problem by providing a **fully in-org alternative** — secure, extensible, and customizable.

---

## 🔧 Features

### 🔍 Query Runner

* Run SOQL queries with validation
* Builder mode (no-code query generation)
* Raw query editor with field suggestions
* Pagination support
  <img width="1859" height="880" alt="image" src="https://github.com/user-attachments/assets/b8779035-132d-41b3-85e2-300fb6390a1d" />
  <img width="1661" height="883" alt="image" src="https://github.com/user-attachments/assets/8f8fde59-e5bb-4b7e-acd8-cda3afec38b5" />



### 🧠 Object Explorer

* Explore objects and fields
* View metadata (type, length, required, etc.)
* Inspect relationships
<img width="1640" height="827" alt="image" src="https://github.com/user-attachments/assets/12f1b01e-324d-4df1-b8b5-a855a164dd45" />


### 📄 Record Viewer

* Fetch and view single records
* Edit and update records
* Delete records
  <img width="1633" height="875" alt="image" src="https://github.com/user-attachments/assets/bc18e98f-a6ea-409d-919b-5be63293a30e" />


### ✏️ Data Editor

* Bulk inline editing
* Bulk delete
* Track changed records only
* Export data to CSV
<img width="1668" height="790" alt="image" src="https://github.com/user-attachments/assets/67acc5fb-79b4-4e39-9bb5-1dec604ee786" />


### ⚙️ Org Utilities

* API & storage limits overview
* Metadata summary
* Clear Apex logs
* Field usage analysis
<img width="1677" height="783" alt="image" src="https://github.com/user-attachments/assets/12dc8526-896e-402f-8562-474e7801bcca" />

---

## 🏗️ Architecture

* **Frontend:** Lightning Web Components (LWC)
* **Backend:** Apex Controller (`QueryRunnerController`)
* **APIs Used:**

  * Salesforce REST API
  * Tooling API
* **Security:** Same-org callouts via Named Credentials

All features are unified through a **single Apex controller acting as an API facade**, ensuring clean and scalable architecture.

---

## 📦 Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/doomedToCODE/salesforce-dev-toolkit.git
```

### 2. Deploy to Salesforce Org

```bash
sfdx force:source:deploy -p force-app
```

### 3. Setup Named Credential

* Create Named Credential for same-org callouts
* Configure authentication (OAuth recommended)

### 4. Assign Permissions

* Assign required permission set to users

### 5. Open App

* Navigate to **Dev_Toolkit** tab in Salesforce

---

## 🔒 Security Highlights

* No external browser extensions
* No data leaves Salesforce org
* Respects object & field-level security
* Uses authenticated API calls

---

## 🛣️ Roadmap

* Query history
* Saved queries
* Smarter autocomplete
* UI improvements
* Performance optimizations

---

## 🤝 Contributing

Contributions are welcome!

* Fork the repo
* Create a feature branch
* Submit a PR

---

## 📄 License

MIT License

---

## ⭐ Support

If you find this useful, consider giving it a ⭐ on GitHub!
