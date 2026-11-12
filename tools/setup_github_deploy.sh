#!/usr/bin/env bash
# One-time setup so the GitHub "Deploy" workflow can deploy to Firebase
# without a key: paste this into Cloud Shell for battlebaseball-prod as a
# project owner. Safe to run again; it skips what already exists.
#
# It creates the github-deploy service account with only the roles a deploy
# needs, and lets GitHub Actions runs from jfreema/BattleBaseball's main
# branch act as it. The provider path it prints is already in
# .github/workflows/deploy.yml.
set -u
PROJECT=battlebaseball-prod
REPO=jfreema/BattleBaseball
SA=github-deploy@$PROJECT.iam.gserviceaccount.com

gcloud config set project "$PROJECT" --quiet
PN=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')

gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com --quiet

gcloud iam service-accounts describe "$SA" >/dev/null 2>&1 ||
  gcloud iam service-accounts create github-deploy --display-name="GitHub deploy" --quiet

for ROLE in roles/firebasehosting.admin roles/firebaserules.admin roles/datastore.indexAdmin \
            roles/serviceusage.serviceUsageConsumer roles/serviceusage.apiKeysViewer; do
  gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" \
    --role="$ROLE" --condition=None --quiet >/dev/null && echo "granted $ROLE"
done

gcloud iam workload-identity-pools describe github --location=global >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools create github --location=global --display-name="GitHub" --quiet

gcloud iam workload-identity-pools providers describe battlebaseball --location=global \
    --workload-identity-pool=github >/dev/null 2>&1 ||
  gcloud iam workload-identity-pools providers create-oidc battlebaseball --location=global \
    --workload-identity-pool=github --display-name="BattleBaseball main" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition="assertion.repository=='$REPO' && assertion.ref=='refs/heads/main'" --quiet

gcloud iam service-accounts add-iam-policy-binding "$SA" --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$PN/locations/global/workloadIdentityPools/github/attribute.repository/$REPO" \
  --quiet >/dev/null && echo "linked $REPO to $SA"

echo
echo "Done. Provider: projects/$PN/locations/global/workloadIdentityPools/github/providers/battlebaseball"
