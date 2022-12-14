##
# SUBREPO

# target subrepo-branch-delete: Delete branch $(BRANCH) on remote $(SUBREPO)
.PHONY: subrepo-branch-delete
subrepo-branch-delete: myos-user subrepo-check
ifneq ($(words $(BRANCH)),0)
	[ $$(git ls-remote --heads $(REMOTE) $(BRANCH) 2>/dev/null |wc -l) -eq 1 ] \
	 && $(RUN) git push $(REMOTE) :$(BRANCH)
endif

# target subrepo-check: Define SUBREPO and REMOTE
.PHONY: subrepo-check
subrepo-check:
ifeq ($(words $(ARGS)), 0)
ifeq ($(words $(SUBREPO)), 0)
	$(error Please provide a SUBREPO)
endif
endif
	$(eval SUBREPO ?= $(word 1, $(ARGS)))
	$(eval REMOTE  := subrepo/$(SUBREPO))

# target subrepo-git-diff: Check if monorepo is up to date with subrepo
# subrepo-push saves the parent commit in file subrepo/.gitrepo
## it gets parent commit in .gitrepo : awk '$1 == "parent" {print $3}' subrepo/.gitrepo
## it gets child of parent commit : git rev-list --ancestry-path parent..HEAD |tail -n 1
## it compares child commit with our tree : git diff --quiet child -- subrepo
.PHONY: subrepo-git-diff
subrepo-git-diff: myos-user subrepo-check
	$(eval IGNORE_DRYRUN := true)
	$(eval DIFF = $(shell git diff --quiet $(shell git rev-list --ancestry-path $(shell awk '$$1 == "parent" {print $$3}' $(SUBREPO)/.gitrepo)..HEAD |tail -n 1) -- $(SUBREPO); printf '$$?\n') )
	$(eval IGNORE_DRYRUN := false)

# target subrepo-git-fetch: Fetch git remote
.PHONY: subrepo-git-fetch
subrepo-git-fetch: myos-user subrepo-check
	$(RUN) git fetch --prune $(REMOTE)

# target subrepo-tag-create-%: Create tag TAG to reference branch REMOTE/%
.PHONY: subrepo-tag-create-%
subrepo-tag-create-%: myos-user subrepo-check subrepo-git-fetch
ifneq ($(words $(TAG)),0)
	[ $$(git ls-remote --tags $(REMOTE) $(TAG) |wc -l) -eq 0 ] \
	 || $(call exec,$(RUN) git push $(REMOTE) :refs/tags/$(TAG))
	$(RUN) git push $(REMOTE) refs/remotes/subrepo/$(SUBREPO)/$*:refs/tags/$(TAG)
endif

# target subrepo-push: Push to subrepo
.PHONY: subrepo-push
subrepo-push: myos-user subrepo-check subrepo-git-fetch subrepo-git-diff
# update .gitrepo only on master branch
ifeq ($(BRANCH),master)
	$(eval UPDATE_SUBREPO_OPTIONS += -u)
endif
# if specific branch name, delete remote branch before push and recreate it from master
ifneq ($(findstring $(firstword $(subst /, ,$(BRANCH))),feature hotfix release story),)
	$(eval IGNORE_DRYRUN := true)
	$(eval DELETE = $(shell sh -c 'git ls-remote --heads $(REMOTE) $(BRANCH) |wc -l') )
	$(eval IGNORE_DRYRUN := false)
else
	$(eval DELETE = 0)
endif
	if [ $(DIFF) -eq 0 ]; then \
		$(call INFO,subrepo $(SUBREPO) already up to date); \
	else \
		if [ $(DELETE) -eq 1 ]; then \
			$(RUN) git push $(REMOTE) :$(BRANCH); \
			$(RUN) git push $(REMOTE) refs/remotes/$(REMOTE)/master:refs/heads/$(BRANCH); \
		fi; \
		$(RUN) git subrepo fetch $(SUBREPO) -b $(BRANCH); \
		$(RUN) git subrepo push $(SUBREPO) -b $(BRANCH) $(UPDATE_SUBREPO_OPTIONS); \
		$(RUN) git subrepo clean $(SUBREPO); \
	fi

# target subrepos-branch-delete: Fire APPS target
.PHONY: subrepos-branch-delete
subrepos-branch-delete: $(APPS) ;

# target subrepos-tag-create-%: Fire APPS target
.PHONY: subrepos-tag-create-%
subrepos-tag-create-%: $(APPS) ;

# target subrepos-update: Fire APPS target and push updates to upstream
.PHONY: subrepos-update
subrepos-update: myos-user git-stash $(APPS) git-unstash ## Update subrepos
	$(RUN) git push upstream $(BRANCH)

# target subrepo-update-%: Call subrepo-update target in folder %
.PHONY: subrepo-update-%
subrepo-update-%:
	$(if $(wildcard $*/Makefile),$(call make,subrepo-update,$*))
