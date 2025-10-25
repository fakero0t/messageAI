<!-- a1703640-a935-4815-81c4-5b303646ee5e cf8965b5-1efc-4720-b7e8-18d99fcbb112 -->
# Learning Upgrade Task List Creation

## Overview

Create `learning_upgrade_task_list.md` that breaks down the 5-signal word validation system into 6 sequential pull requests, each with complete implementation details.

## Document Structure

The task list will include:

### PR1: Database Foundation & Word Tracking

- Create Firestore collections: `wordStats`, `gptValidations`
- Implement word usage tracking function
- Add database indexes for performance
- Files to modify: Create new `functions/wordValidation.js`
- Database rules updates for new collections
- Testing: Verify tracking increments properly

### PR2: Free Validation Signals (Crowd + Patterns)

- Implement crowd wisdom validation function
- Check unique user count
- Return confidence scores based on thresholds (10+, 5+, 3+ users)
- Implement linguistic pattern analysis
- Georgian vowel/consonant ratio checks
- Excessive repetition detection
- Character validation
- Files to modify: `functions/wordValidation.js`
- Testing: Unit tests for pattern matching, crowd validation

### PR3: GPT-Based Validation Signals

- Implement GPT word validation
- Simple yes/no prompt
- Firestore caching (1 week TTL)
- Implement translation round-trip consistency
- Georgian → English → Georgian
- Similarity calculation (Levenshtein distance)
- Cache translation results
- Files to modify: `functions/wordValidation.js`
- Reuse existing OpenAI helper functions
- Testing: Validate caching works, test similarity calculations

### PR4: Semantic Embedding Validation

- Implement embedding generation for words
- Create seed list of 100 verified Georgian words
- Implement cosine similarity comparison
- Cache embeddings for verified words
- Files to modify: `functions/wordValidation.js`
- Testing: Verify embeddings cluster correctly

### PR5: Master Validation Function

- Implement weighted signal combination
- Configure signal weights (crowd: 1.0, translation: 0.85, gpt: 0.80, semantic: 0.70, patterns: 0.60)
- Add early exit logic (crowd_strong, failed_patterns)
- Implement 0.65 threshold decision
- Add comprehensive logging
- Files to modify: `functions/wordValidation.js`
- Testing: Integration tests with various word types

### PR6: Practice Function Integration

- Update `extractValidGeorgianWords()` to use new validation
- Pass userId through validation chain
- Update GPT prompts to emphasize validated words only
- Add validation metrics logging
- Files to modify: `functions/practiceFunction.js`
- Update existing validation calls
- Testing: End-to-end practice generation with new validation

## PR Details Format

Each PR section will include:

- PR title and description
- Goals and acceptance criteria
- Files to create/modify with specific function signatures and key logic descriptions
- Database changes required (schemas, indexes)
- Firebase Security Rules updates
- Setup instructions (if any configuration changes needed)
- Integration points with existing code
- Testing requirements
- Performance considerations
- Rollback plan

## Additional Document Sections

### Setup Instructions (Beginning of Document)

- Firebase configuration requirements
- Environment variables needed
- Initial database setup steps
- Any prerequisite changes

### Security Rules (Included in Each PR)

- Firestore security rules for new collections
- Read/write permissions
- Validation rules

## Success Criteria

- Each PR can be implemented independently
- Clear dependencies between PRs
- Complete enough that any developer can implement
- Includes file paths, function names, function signatures, and key logic descriptions
- Security rules included where applicable
- Setup instructions for any configuration changes
- Testing strategy for each PR

Create file: `learning_upgrade_task_list.md` in project root with all 6 PRs detailed as described above.