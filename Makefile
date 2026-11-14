##
## Stub Makefile used by the CI smoke tests of this repository.
## Real projects provide their own Makefile.
##

ci-setup:
	@echo "CI setup done"

tests-with-coverage:
	@echo "Running stub tests"
	@touch coverage.info junit.xml
	@mkdir -p .cache extra
	@echo "smoke" > .cache/smoke.txt
	@echo "smoke" > extra/smoke.txt

ci-post-run:
	@echo "Post run done"

scan-reports:
	@echo "[]" > clippy.json
