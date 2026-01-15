#!/bin/bash

# Script to orchestrate the full experiment workflow:
# 1. Start JMeter Load Test (Steady State + Burst Traffic)
# 2. Trigger Spot Node Preemption Simulation at the correct time
# 3. Collect metrics and generate reports

set -e

# Configuration
JMETER_TEST_PLAN="../tests/load-test-jmeter.jmx"
RESULTS_DIR="../tests/results"
SIMULATION_SCRIPT="../tests/simulation.sh"
STEADY_STATE_DURATION=300  # 5 minutes (300 seconds) - wait before triggering simulation
ITERATIONS=1  # Number of times to run the simulation (set to 20 for statistical validation as per proposal)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Hybrid Kubernetes Cost Optimization"
echo "Experiment Orchestration Script"
echo "========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v jmeter &> /dev/null; then
    echo -e "${RED}Error: JMeter is not installed or not in PATH.${NC}"
    echo "Please install Apache JMeter: https://jmeter.apache.org/download_jmeter.cgi"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible.${NC}"
    exit 1
fi

if [ ! -f "$JMETER_TEST_PLAN" ]; then
    echo -e "${RED}Error: JMeter test plan not found at $JMETER_TEST_PLAN${NC}"
    exit 1
fi

if [ ! -f "$SIMULATION_SCRIPT" ]; then
    echo -e "${RED}Error: Simulation script not found at $SIMULATION_SCRIPT${NC}"
    exit 1
fi

# Get the service/ingress IP
echo ""
echo "Retrieving application endpoint..."
SERVICE_IP=$(kubectl get svc hybrid-autoscaling-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$SERVICE_IP" ]; then
    echo -e "${YELLOW}Warning: LoadBalancer service not found. Checking for NodePort...${NC}"
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    NODE_PORT=$(kubectl get svc hybrid-autoscaling-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
    if [ -n "$NODE_IP" ] && [ -n "$NODE_PORT" ]; then
        SERVICE_IP="${NODE_IP}:${NODE_PORT}"
    else
        echo -e "${RED}Error: Could not determine application endpoint.${NC}"
        echo "Please ensure the application is deployed and accessible."
        exit 1
    fi
fi

echo -e "${GREEN}Application endpoint: $SERVICE_IP${NC}"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Update JMeter test plan with the correct host
echo ""
echo "Updating JMeter test plan with endpoint: $SERVICE_IP"
# Note: This is a simple sed replacement. In production, consider using JMeter properties (-J flag)
sed -i.bak "s/<stringProp name=\"Argument.value\">.*<\/stringProp> <!-- REPLACE WITH YOUR INGRESS IP -->/<stringProp name=\"Argument.value\">$SERVICE_IP<\/stringProp> <!-- REPLACE WITH YOUR INGRESS IP -->/" "$JMETER_TEST_PLAN"

echo ""
echo "========================================="
echo "Starting Experiment"
echo "========================================="
echo ""

for i in $(seq 1 $ITERATIONS); do
    echo -e "${GREEN}=== Iteration $i of $ITERATIONS ===${NC}"
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    RESULT_FILE="$RESULTS_DIR/results_${TIMESTAMP}.jtl"
    LOG_FILE="$RESULTS_DIR/jmeter_${TIMESTAMP}.log"
    
    # Start JMeter in background
    echo "Starting JMeter load test..."
    jmeter -n -t "$JMETER_TEST_PLAN" -l "$RESULT_FILE" -j "$LOG_FILE" &
    JMETER_PID=$!
    
    echo -e "${GREEN}JMeter started (PID: $JMETER_PID)${NC}"
    echo "Waiting ${STEADY_STATE_DURATION}s for steady state phase..."
    
    # Wait for steady state to establish
    sleep $STEADY_STATE_DURATION
    
    # Trigger spot node preemption
    echo ""
    echo -e "${YELLOW}Triggering Spot Node Preemption Simulation...${NC}"
    bash "$SIMULATION_SCRIPT" 2>&1 | tee "$RESULTS_DIR/simulation_${TIMESTAMP}.log"
    
    echo ""
    echo "Simulation triggered. Waiting for JMeter to complete..."
    
    # Wait for JMeter to finish
    wait $JMETER_PID
    JMETER_EXIT_CODE=$?
    
    if [ $JMETER_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}JMeter test completed successfully.${NC}"
    else
        echo -e "${YELLOW}JMeter exited with code $JMETER_EXIT_CODE (this may be normal if errors were expected during failover).${NC}"
    fi
    
    # Generate HTML report
    echo "Generating HTML report..."
    REPORT_DIR="$RESULTS_DIR/report_${TIMESTAMP}"
    jmeter -g "$RESULT_FILE" -o "$REPORT_DIR"
    
    echo -e "${GREEN}HTML report generated: $REPORT_DIR/index.html${NC}"
    echo ""
    
    if [ $i -lt $ITERATIONS ]; then
        echo "Waiting 60s before next iteration..."
        sleep 60
    fi
done

echo ""
echo "========================================="
echo "Experiment Complete!"
echo "========================================="
echo ""
echo "Results saved in: $RESULTS_DIR"
echo ""
echo "To view the HTML report, open:"
echo "  $RESULTS_DIR/report_*/index.html"
echo ""
echo "Key metrics to collect:"
echo "  - Error Rate: Check 'Statistics' table in HTML report"
echo "  - Latency (p95, p99): Check 'Response Times Percentiles' graph"
echo "  - Failover Time: Analyze timestamps in JMeter log around simulation time"
echo ""
echo "For infrastructure metrics (CPU, Pod Restarts):"
echo "  - Access Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo ""
