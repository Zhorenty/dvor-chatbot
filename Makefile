.PHONY: bot bot-stop bot-restart

BOT_CMD := dart run bin/dvor_bot.dart
BOT_MATCH := bin/dvor_bot.dart

bot:
	$(BOT_CMD)

bot-stop:
	@pkill -f "$(BOT_MATCH)" >/dev/null 2>&1 || true

bot-restart: bot-stop
	$(BOT_CMD)
