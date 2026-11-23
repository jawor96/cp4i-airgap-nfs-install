# Instrukcja Wdrożenia IBM Cloud Pak for Integration (CP4I 16.2.0)
## Zakres: Platform UI, IBM MQ oraz App Connect Enterprise (Integration Runtime z ACH)
### Środowisko: Red Hat OpenShift Container Platform (OCP) Air-Gapped + NFS Storage

---

### Oficjalna Dokumentacja Referencyjna IBM:
- **IBM Cloud Pak for Integration (16.2.0 LTS)**: [https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.2.0](https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.2.0)
- **IBM Cloud Pak for Integration - Operator and instance versions**: [https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.2.0?topic=reference-operator-instance-versions-this-release](https://www.ibm.com/docs/en/cloud-paks/cp-integration/16.2.0?topic=reference-operator-instance-versions-this-release)
- **IBM MQ (10.0.x LTS)**: [https://www.ibm.com/docs/en/ibm-mq/10.0.x](https://www.ibm.com/docs/en/ibm-mq/10.0.x)
- **IBM MQ License Service Customization**: [https://www.ibm.com/docs/en/ibm-mq/10.0.x?topic=examples-example-customizing-license-service-annotations](https://www.ibm.com/docs/en/ibm-mq/10.0.x?topic=examples-example-customizing-license-service-annotations)
- **IBM App Connect Enterprise (13.0.x LTS)**: [https://www.ibm.com/docs/en/app-connect/13.0.x](https://www.ibm.com/docs/en/app-connect/13.0.x)
- **IBM App Connect for Healthcare Licensing in Containers**: [https://www.ibm.com/docs/en/app-connect/13.0.x?topic=iu-installing-license-service-adding-annotations-app-connect-healthcare-in-containers](https://www.ibm.com/docs/en/app-connect/13.0.x?topic=iu-installing-license-service-adding-annotations-app-connect-healthcare-in-containers)

---

## 1. Wstęp i Tabela Wersji

Niniejsze repozytorium stanowi kompletny, niezależny zestaw manifestów Kubernetes/OpenShift oraz skryptów powłoki (`bash`) umożliwiający przeprowadzenie wdrożenia **IBM Cloud Pak for Integration (CP4I 16.2.0 LTS)** w środowisku **odizolowanym (air-gapped)** na klastrze **Red Hat OpenShift (OCP)** z pamięcią masową opartą na protokole **NFS**.

### Tabela Wersji i Kanałów Operatorów (CP4I 16.2.0 LTS / SC2):

| Komponent | Kanał OLM | Wersja Instancji / CR | Typ Licencji |
|---|---|---|---|
| **Red Hat OpenShift Cert-Manager** | `stable-v1` | v1.x | OpenShift Entitlement |
| **IBM Cloud Pak foundational services** | `v4.19` | 4.19.x (Keycloak + PostgreSQL) | Foundational Services |
| **IBM Integration Platform Navigator** | `v8.3-sc2` | `16.2.0` | `L-VAD2-N2WPMY` |
| **IBM MQ Operator** | `v4.0-sc2` | `10.0.0.5-r2` | `L-VEMB-RABZSN` (`productMetric: FREE`) |
| **IBM App Connect Operator** | `v13.6` | `13.0.9.0-r1` | `L-RJGW-BUAA2R` |
| **App Connect for Healthcare (ACH)** | `v13.6` | `13.0.9.0-r1` | ID: `563f8a6f0cea439eacc2cad8215dea7d` |

---

## 2. Wymagania Wstępne i Przygotowanie

### Narzędzia wymagane na stacji administratora:
- `oc` (OpenShift CLI) – zalogowany do klastra z uprawnieniami `cluster-admin`
- `jq` – parser JSON
- `base64` – narzędzie kodowania danych
- `openssl` – narzędzie kryptograficzne

### Konfiguracja parametrów w `env.sh`:
Przed rozpoczęciem instalacji zweryfikuj lub zmodyfikuj zmienne w pliku [`env.sh`](env.sh):
```bash
# Główne zmienne konfiguracyjne
export CP4I_NAMESPACE="cp4i"
export OPERATOR_NAMESPACE="openshift-operators"
export CS_NAMESPACE="ibm-common-services"
export NFS_STORAGE_CLASS="nfs-client"
export CATALOG_SOURCE="ibm-operator-catalog"
export CERT_MANAGER_CATALOG="redhat-operators"
```

---

## 3. Struktura Repozytorium

```text
.
├── README.md                                # Niniejsza instrukcja krok po kroku
├── ARCHITECTURE.md                          # Szczegółowy opis architektury i powiązań
├── env.sh                                   # Centralne zmienne konfiguracyjne
│
├── 01-prerequisites/                        # Wymagania wstępne
│   ├── 00-storageclass-nfs.yaml             # Przykładowy szablon StorageClass NFS
│   ├── 01-namespaces.yaml                   # Przestrzenie nazw (cp4i, ibm-common-services, cert-manager-operator, cert-manager)
│   ├── 02-operator-group.yaml               # OperatorGroup dla Cert-Managera
│   ├── 03-catalog-sources.yaml              # CatalogSource dla środowiska Air-Gapped (digest)
│   └── 04-clusterissuer-cert-manager.yaml   # Cert-Manager PKI (Root CA w cert-manager + ClusterIssuer)
│
├── 02-operators/                            # Subskrypcje Operatorów OLM (LTS)
│   ├── 00-cert-manager-subscription.yaml    # Red Hat OpenShift Cert-Manager (stable-v1)
│   ├── 01-common-services-subscription.yaml # IBM Cloud Pak Foundational Services (v4.19)
│   ├── 02-platform-navigator-sub.yaml       # IBM Integration Platform Navigator (v8.3-sc2)
│   ├── 03-mq-subscription.yaml              # IBM MQ Operator (v4.0-sc2)
│   └── 04-app-connect-subscription.yaml     # IBM App Connect Operator (v13.6)
│
├── 03-platform-ui/                          # Konfiguracja i Wdrożenie Platform UI
│   ├── 01-common-services-config.yaml       # Konfiguracja CommonService (StorageClass NFS)
│   ├── 02-platform-navigator-instance.yaml  # Instancja PlatformNavigator CR (16.2.0)
│   └── 03-get-access-info.sh                # Skrypt pobierania adresu URL i haseł
│
├── 04-mq/                                   # Konfiguracja i Wdrożenie IBM MQ
│   ├── 01-mq-pki-certificate.yaml           # Certyfikat TLS dla MQ (Cert-Manager)
│   ├── 02-mq-tls-route.yaml                 # OpenShift Route Passthrough SNI (extapp2e-to2e-mq.chl.mq.ibm.com)
│   ├── 03-mq-mqsc-configmap.yaml            # Bezpieczny ConfigMap MQSC (CHLAUTH, SSLPEERMAP, uprawnienia OAM)
│   ├── 04-mq-ini-configmap.yaml             # Minimalny ConfigMap qm.ini (parametry Log)
│   └── 05-queuemanager-instance.yaml        # QueueManager CR (10.0.0.5-r2 + pki.trust + licencja ACE FREE)
│
├── 05-ace/                                  # Konfiguracja i Wdrożenie App Connect & ACH
│   ├── 01-ace-dashboard-instance.yaml       # Instancja App Connect Dashboard (NFS RWX, 13.0.9.0-r1)
│   ├── 02-ace-config-mq-policy.yaml         # Configuration CR: policyproject dla MQ (poprawny ZIP base64)
│   ├── 03-ace-config-serverconf-ach.yaml    # Configuration CR: serverconf dla ACH (remoteDefaultQueueManager)
│   ├── 04-ace-config-barauth.yaml           # Configuration CR: barauth (szablon autoryzacji)
│   ├── 05-ace-integration-runtime.yaml      # IntegrationRuntime CR (przypięta wersja 13.0.9.0-r1)
│   └── 06-ace-ach-hl7-integration-runtime.yaml # IntegrationRuntime ACH (adnotacje licencyjne + NodePort MLLP)
│
└── scripts/                                 # Skrypty automatyzujące poszczególne etapy
    ├── 00-common.sh                         # Wspólne biblioteki i funkcje pomocnicze
    ├── 01-setup-prerequisites.sh            # Wykonanie Kroku 1
    ├── 02-install-operators.sh              # Wykonanie Kroku 2 (LTS kanały z env.sh)
    ├── 03-deploy-platform-ui.sh             # Wykonanie Kroku 3 (patch CommonServices + PlatformNavigator)
    ├── 04-deploy-mq.sh                      # Wykonanie Kroku 4 (MQ v10 + certyfikaty CA + trust)
    ├── 05-deploy-ace-dashboard.sh           # Wykonanie Kroku 5 (Dashboard RWX)
    ├── 06-deploy-ace-integrations.sh        # Wykonanie Kroku 6 (Konfiguracje + IR bazowy i ACH)
    ├── 99-verify-all.sh                     # Pełna weryfikacja stanu środowiska
    └── 99-get-all-access-info.sh            # Zestawienie adresów URL, konsol i danych logowania
```

---

## 4. Instrukcja Instalacji Krok po Kroku

### Krok 1: Przygotowanie Klastra, Przestrzeni Nazw, StorageClass i Cert-Managera

W tym kroku tworzymy przestrzenie nazw `cp4i`, `ibm-common-services`, `cert-manager-operator` oraz `cert-manager`, weryfikujemy StorageClass NFS, aplikujemy lokalne `CatalogSource` oraz instalujemy **Red Hat OpenShift Cert-Manager Operator** wraz z hierarchią CA (`ClusterIssuer`).

#### Wykonanie manualne:
```bash
# 1.1 Tworzenie przestrzeni nazw
oc apply -f 01-prerequisites/01-namespaces.yaml

# 1.2 Aplikacja CatalogSource (jeśli nie istnieje w klastrze)
oc apply -f 01-prerequisites/03-catalog-sources.yaml

# 1.3 Instalacja Cert-Manager Operator
oc apply -f 01-prerequisites/02-operator-group.yaml
oc apply -f 02-operators/00-cert-manager-subscription.yaml

# 1.4 Oczekiwanie na gotowość operatora cert-manager
oc wait --for=jsonpath='{.status.phase}'=Succeeded csv -l operators.coreos.com/openshift-cert-manager-operator.cert-manager-operator -n cert-manager-operator --timeout=300s

# 1.5 Utworzenie łańcucha PKI (Root CA w cert-manager + ClusterIssuer)
oc apply -f 01-prerequisites/04-clusterissuer-cert-manager.yaml
oc wait --for=condition=Ready certificate/cp4i-root-ca-cert -n cert-manager --timeout=300s
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/01-setup-prerequisites.sh
```

---

### Krok 2: Instalacja Operatorów CP4I

Instalujemy subskrypcje OLM dla operatorów w kanałach LTS zgodnie z tabelą wersji CP4I 16.2.0:
- IBM Cloud Pak Foundational Services (`v4.19`)
- IBM Integration Platform Navigator (`v8.3-sc2`)
- IBM MQ Operator (`v4.0-sc2`)
- IBM App Connect Operator (`v13.6`)

#### Wykonanie manualne:
```bash
oc apply -f 02-operators/01-common-services-subscription.yaml
oc apply -f 02-operators/02-platform-navigator-sub.yaml
oc apply -f 02-operators/03-mq-subscription.yaml
oc apply -f 02-operators/04-app-connect-subscription.yaml

# Sprawdzenie statusu CSV (wszystkie powinny osiągnąć 'Succeeded'):
oc get csv -n openshift-operators
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/02-install-operators.sh
```

---

### Krok 3: Wdrożenie i Konfiguracja Platform UI

1. Konfigurujemy StorageClass NFS w usługach wspólnych (Common Services / Keycloak).
2. Wdrażamy instancję `PlatformNavigator` (wersja `16.2.0`) w przestrzeni `cp4i`.
3. Pobieramy adres URL oraz poświadczenia administratora (`integration-admin`).

#### Wykonanie manualne:
```bash
# 3.1 Konfiguracja StorageClass w CommonService (patch istniejącego lub apply)
oc patch CommonService common-service -n ibm-common-services --type=merge --patch '{"spec":{"storageClass":"nfs-client"}}' 2>/dev/null || oc apply -f 03-platform-ui/01-common-services-config.yaml

# 3.2 Wdrożenie Platform UI
oc apply -f 03-platform-ui/02-platform-navigator-instance.yaml -n cp4i

# 3.3 Oczekiwanie na status Ready
oc wait --for=condition=Ready platformnavigator/cp4i-navigator -n cp4i --timeout=900s

# 3.4 Pobranie poświadczeń
./03-platform-ui/03-get-access-info.sh
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/03-deploy-platform-ui.sh
```

---

### Krok 4: Wdrożenie IBM MQ (Supporting Program dla ACE)

Wdrażamy instancję IBM MQ w trybie `SingleInstance` z wolumenem opartym na NFS oraz adnotacjami licencyjnymi dla IBM License Service:
1. Generowanie certyfikatów TLS (`Certificate` CR powiązany z `gitops-selfsigned-issuer`).
2. Trasa OpenShift Passthrough SNI (`extapp2e-to2e-mq.chl.mq.ibm.com` do portu 1414).
3. Bezpieczne definicje MQSC (aktywny CHLAUTH, SSLPEERMAP, zablokowany `mqm`, dedykowany `aceapp` i `extapp`) oraz `qm.ini`.
4. Instancja `QueueManager` z wersją `10.0.0.5-r2`, zaufanym CA w `spec.pki.trust` i adnotacją `spec.annotations.productMetric: FREE`.

#### Wykonanie manualne:
```bash
# 4.1 Certyfikat TLS i Route
oc apply -f 04-mq/01-mq-pki-certificate.yaml -n cp4i
oc apply -f 04-mq/02-mq-tls-route.yaml -n cp4i

# 4.2 Oczekiwanie na certyfikat
oc wait --for=condition=Ready certificate/qmgr-demo-selfsigned-cert -n cp4i --timeout=300s

# 4.3 Definicje MQSC i INI
oc apply -f 04-mq/03-mq-mqsc-configmap.yaml -n cp4i
oc apply -f 04-mq/04-mq-ini-configmap.yaml -n cp4i

# 4.4 Utworzenie instancji QueueManager
oc apply -f 04-mq/05-queuemanager-instance.yaml -n cp4i

# 4.5 Oczekiwanie na fazę Running
oc wait --for=jsonpath='{.status.phase}'=Running queuemanager/qmgr-demo -n cp4i --timeout=600s
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/04-deploy-mq.sh
```

---

### Krok 5: Wdrożenie App Connect Dashboard (Content Server na NFS RWX)

App Connect Dashboard udostępnia interfejs graficzny oraz Content Server. Wymaga wolumenu **RWX (ReadWriteMany)**, który jest dostarczany przez StorageClass NFS.

#### Wykonanie manualne:
```bash
# 5.1 Wdrożenie Dashboard CR
oc apply -f 05-ace/01-ace-dashboard-instance.yaml -n cp4i

# 5.2 Oczekiwanie na fazę Ready
oc wait --for=jsonpath='{.status.phase}'=Ready dashboard/ace-dashboard -n cp4i --timeout=600s
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/05-deploy-ace-dashboard.sh
```

---

### Krok 6: Wdrożenie Konfiguracji ACE i Instancji Integration Runtime (w tym ACH)

1. Tworzymy obiekty `Configuration` typu:
   - `policyproject` (`ace-qmgr-demo-policy`) – poprawnie sformatowany projekt polityki ZIP z punktem końcowym `QMGRDEMO`.
   - `serverconf` (`umed-default-qmgr`) – konfiguracja `server.conf.yaml` ze wskazaniem `remoteDefaultQueueManager: '{CP4iQMGRDEMO}:QMGRDEMO'`.
   - `barauth` (`local-barauth`) – opcjonalny szablon autoryzacji do pobierania plików BAR.
2. Wdrażamy instancję podstawową `IntegrationRuntime` (`ace-mqapi-runtime` w wersji `13.0.9.0-r1`).
3. Wdrażamy instancję `IntegrationRuntime` dedykowaną dla **App Connect for Healthcare (ACH)** (`ace-ach-hl7-runtime`) wraz z poprawnymi adnotacjami licencyjnymi dla License Service oraz dedykowaną usługą NodePort (port TCP: 1111 / 30131) dla ruchu MLLP/HL7.

#### Wykonanie manualne:
```bash
# 6.1 Aplikowanie konfiguracji
oc apply -f 05-ace/02-ace-config-mq-policy.yaml -n cp4i
oc apply -f 05-ace/03-ace-config-serverconf-ach.yaml -n cp4i

# 6.2 Wdrożenie Integration Runtime
oc apply -f 05-ace/05-ace-integration-runtime.yaml -n cp4i
oc apply -f 05-ace/06-ace-ach-hl7-integration-runtime.yaml -n cp4i

# 6.3 Sprawdzenie stanu
oc get integrationruntime -n cp4i
```

#### Wykonanie za pomocą skryptu automatycznego:
```bash
./scripts/06-deploy-ace-integrations.sh
```

---

## 5. Weryfikacja i Dane Dostępowe

### Pełna weryfikacja stanu wdrożenia:
Uruchom:
```bash
./scripts/99-verify-all.sh
```

### Wyświetlenie adresów URL, konsol i poświadczeń:
Uruchom:
```bash
./scripts/99-get-all-access-info.sh
```

Otrzymasz kompletne zestawienie:
- **Platform UI**: Adres URL, login (`integration-admin`) oraz hasło początkowe pobrane z sekretu `integration-admin-initial-temporary-credentials`.
- **IBM MQ**: Wewnętrzny adres usługi `qmgr-demo-ibm-mq.cp4i.svc.cluster.local:1414`, bezpieczne kanały `ACE.TO.MQ` (wewnątrz klastra) i `EXTAPP.TO.MQ` (TLS 1.3 przez Passthrough Route SNI), konsola Web.
- **App Connect Dashboard**: Adres URL UI oraz kafelka w Platform UI.
- **ACH (App Connect for Healthcare)**: Port MLLP TCP 1111 (NodePort 30131), kolejki `HL7.INPUT.Q`, `HL7.OUTPUT.Q`, `HL7.ERROR.Q`.

---

## 6. Wymagania i Uwagi Dotyczące Pamięci NFS (Storage Considerations)

1. **Wymagania NFS dla IBM MQ**:
   - IBM MQ wymaga stabilnego systemu plików z pełną obsługą semantyki blokowania POSIX (NFSv4 z poprawnie działającym `rpc.statd` / `rpc.lockd`).
   - Przed produkcyjnym użyciem zaleca się wykonanie testu zgodności systemu plików narzędziem `amqmfsck` dostarczanym z IBM MQ.
2. **Prawa dostępu i uprawnienia**:
   - Eksport NFS dla wolumenów klastra powinien być skonfigurowany z flagą `no_root_squash` na serwerze NFS, aby umożliwić procesom OpenShift zarządzanie właścicielami UID/GID w ramach przydzielonych zakresów `fsGroup` (SCC `restricted` / `nonroot`).
3. **Współdzielenie RWX dla App Connect Dashboard**:
   - Dashboard (Content Server) wymaga wolumenu w trybie `ReadWriteMany` (RWX), co jest natywną funkcjonalnością NFS.
