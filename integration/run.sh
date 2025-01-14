#!/usr/bin/env ksh

run_tests() {
	test_name=$1
	num_tests=$2

	success_count=0
	failure_count=0
	runtimes=()

	echo "-------------------"
	echo "Running Tests for $test_name"

	for ((i = 1; i <= num_tests; i++)); do
		docker network prune -f >/dev/null 2>&1
		docker rm headscale-test-suite || true
		docker kill "$(docker ps -q)" || true

		start=$(date +%s)
		docker run \
			--tty --rm \
			--volume ~/.cache/hs-integration-go:/go \
			--name headscale-test-suite \
			--volume "$PWD:$PWD" -w "$PWD"/integration \
			--volume /var/run/docker.sock:/var/run/docker.sock \
			--volume "$PWD"/control_logs:/tmp/control \
			golang:1 \
			go test ./... \
			-failfast \
			-timeout 120m \
			-parallel 1 \
			-run "^$test_name\$" >/dev/null 2>&1
		status=$?
		end=$(date +%s)

		runtime=$((end - start))
		runtimes+=("$runtime")

		if [ "$status" -eq 0 ]; then
			((success_count++))
		else
			((failure_count++))
		fi
	done

	echo "-------------------"
	echo "Test Summary for $test_name"
	echo "-------------------"
	echo "Total Tests: $num_tests"
	echo "Successful Tests: $success_count"
	echo "Failed Tests: $failure_count"
	echo "Runtimes in seconds: ${runtimes[*]}"
	echo
}

# Check if both arguments are provided
if [ $# -ne 2 ]; then
	echo "Usage: $0 <test_name> <num_tests>"
	exit 1
fi

test_name=$1
num_tests=$2

docker network prune -f

if [ "$test_name" = "all" ]; then
	rg --regexp "func (Test.+)\(.*" ./integration/ --replace '$1' --no-line-number --no-filename --no-heading | sort | while read -r test_name; do
		run_tests "$test_name" "$num_tests"
	done
else
	run_tests "$test_name" "$num_tests"
fi
