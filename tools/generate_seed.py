#!/usr/bin/env python3
"""Generate supabase/seed/actions.json and supabase/seed/seed_actions.sql.

2500 mood-specific tasks: 25 moods x 20 base tasks x 5 variants.
Each task is tagged for exactly ONE mood.
Repeatable: ON CONFLICT (title) DO NOTHING.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- helpers

def _categorize(mood, title):
    """Derive category and sub_category from task text."""
    t = title.lower()
    # movement / physical
    movement = any(w in t for w in [
        "jump", "jacks", "dance", "squats", "push-up", "burpee", "plank",
        "sprint", "march", "lunge", "punch", "shadowbox", "high knee",
        "star jump", "lap of", "victory dance", "victory pose", "happy spin",
        "climb", "shake", "kick", "clap", "stomp", "fist-pump",
    ])
    # breathing
    breathing = any(w in t for w in [
        "breath", "breathe", "exhale", "inhale", "sigh", "hum",
    ])
    # grounding
    grounding = any(w in t for w in [
        "ground", "5-4-3-2-1", "notice", "count", "scan", "ice cube",
        "cold water", "splash", "feel your feet", "body check", "unclench",
        "muscle", "tension",
    ])
    # writing / reflection
    writing = any(w in t for w in [
        "write down", "write a", "list", "journal", "letter", "note",
        "doodle", "sketch", "brainstorm", "plan", "mission statement",
        "checklist", "rank", "rate", "draw", "pros and cons", "caption",
        "line",
    ])
    # social
    social = any(w in t for w in [
        "text", "message", "friend", "someone", "call", "voice",
        "share", "connect", "reconnect", "check in",
    ])
    # planning / productivity
    planning = any(w in t for w in [
        "to-do", "to do", "to-do list", "next step", "break", "organize",
        "tidy", "task", "do one", "do a small", "brain dump", "posture reset",
        "set a reminder",
    ])
    # gratitude
    gratitude = any(w in t for w in [
        "grateful", "appreciat", "thank", "good thing", "comfort",
        "small win", "going well", "satisfied", "enough", "simple pleasure",
    ])
    # self-soothing
    self_soothe = any(w in t for w in [
        "self-hug", "kind sentence", "kind act", "pet", "photo", "song",
        "music", "comfort", "soft", "warm", "cozy", "favorite", "smile",
        "high five", "cheer", "celebrate", "moment", "wrap", "blanket",
        "cozy",
    ])
    # sensory / rest
    sensory = any(w in t for w in [
        "look at", "look out", "watch", "listen", "feel", "taste",
        "smell", "hear", "see", "color", "light", "cloud", "sky", "plant",
        "animal", "candle", "water", "sip",
    ])
    # relaxation
    relax = any(w in t for w in [
        "relax", "stretch", "massage", "loosen", "rest your", "close your eyes",
        "soft music", "nature sound", "ambient", "gentle", "child's pose",
        "drop your shoulders", "slowly and mindfully", "calm",
        "stillness", "silence", "sit quietly",
    ])
    # brain / study
    brain = any(w in t for w in [
        "worry postponement", "worst that", "reorder", "rearrange", "word",
        "fact", "learn", "research", "question", "curious", "wiki",
        "history", "experiment", "phrase", "challenge", "brain teaser",
        "riddle", "meaning", "new",
    ])

    # priority-based override for negative-high moods
    if mood in ("angry", "frustrated", "irritable") and movement:
        return "physical", "movement"
    if mood in ("energetic",) and movement:
        return "physical", "movement"
    if mood in ("excited", "elated", "happy", "enthusiastic") and movement:
        return "physical", "movement"

    if breathing:
        return "wellbeing", "breathing"
    if grounding:
        return "wellbeing", "grounding"
    if writing:
        return "reflection", "journaling"
    if social:
        return "social", "message"
    if planning:
        return "reflection", "planning"
    if gratitude:
        return "reflection", "gratitude"
    if relax:
        return "wellbeing", "relaxation"
    if self_soothe:
        return "wellbeing", "self-soothing"
    if sensory:
        return "wellbeing", "rest"
    if brain:
        return "study", "memory"

    # mood-based fallback
    defaults = {
        "excited": ("physical", "movement"),
        "happy": ("wellbeing", "gratitude"),
        "enthusiastic": ("productivity", "planning"),
        "elated": ("wellbeing", "self-soothing"),
        "energetic": ("physical", "movement"),
        "calm": ("wellbeing", "breathing"),
        "content": ("reflection", "gratitude"),
        "relaxed": ("wellbeing", "relaxation"),
        "peaceful": ("wellbeing", "breathing"),
        "serene": ("wellbeing", "rest"),
        "angry": ("physical", "movement"),
        "anxious": ("wellbeing", "grounding"),
        "stressed": ("wellbeing", "relaxation"),
        "irritable": ("wellbeing", "self-soothing"),
        "frustrated": ("wellbeing", "relaxation"),
        "sad": ("wellbeing", "self-soothing"),
        "bored": ("reflection", "journaling"),
        "tired": ("wellbeing", "rest"),
        "depressed": ("wellbeing", "self-soothing"),
        "gloomy": ("wellbeing", "self-soothing"),
        "confused": ("reflection", "planning"),
        "nostalgic": ("reflection", "journaling"),
        "curious": ("study", "memory"),
        "indifferent": ("reflection", "journaling"),
        "surprised": ("wellbeing", "grounding"),
    }
    return defaults[mood]


def _difficulty(title, mood):
    t = title.lower()
    if any(w in t for w in ["push-up", "burpee", "plank", "squat", "sprint", "hiit"]):
        return 3
    if mood in ("energetic", "angry", "frustrated"):
        return 2
    return 1


def _est_minutes(title, mood):
    t = title.lower()
    if any(w in t for w in ["2 minute", "60 second", "30 second", "30-second"]):
        return 2
    if any(w in t for w in ["3 minute", "5 minute"]):
        return 3
    return 2


# ---------------------------------------------------------------- base tasks

MOODS = [
    # positive / high energy
    "excited", "happy", "enthusiastic", "elated", "energetic",
    # positive / low energy
    "calm", "content", "relaxed", "peaceful", "serene",
    # negative / high energy
    "angry", "anxious", "stressed", "irritable", "frustrated",
    # negative / low energy
    "sad", "bored", "tired", "depressed", "gloomy",
    # neutral / mixed
    "confused", "nostalgic", "curious", "indifferent", "surprised",
]

BASE_TASKS = {
    # ===== EXCITED =====
    "excited": [
        "Do 10 jumping jacks to burn off the extra energy",
        "Dance to one upbeat song, full effort",
        "Write down exactly what you're excited about, in detail",
        "Text a friend to share your good news",
        "Make a quick voice memo describing how you feel right now",
        "Do a lap around your home or yard at a fast pace",
        "Plan the very next step toward the thing you're excited about",
        "Do a set of push-ups or squats until you feel the energy settle",
        "Shout or sing the chorus of your favorite song",
        "Sketch or doodle the idea that's exciting you",
        "Set a 2-minute timer and brainstorm everything this could lead to",
        "Take 5 deep, fast breaths, then 5 slow ones to steady yourself",
        "Send a quick message inviting someone to celebrate with you",
        "Fist-pump or clap your hands 20 times",
        "Take a photo or screenshot to remember this moment",
        "Do a 60-second victory pose",
        "Write a one-line goal inspired by this excitement",
        "Star jump for 60 seconds",
        "Make a 3-item list of ways to act on this feeling today",
        "Put your excitement into a two-sentence journal entry",
    ],
    # ===== HAPPY =====
    "happy": [
        "Write down 3 things that made you happy today",
        "Send someone a message telling them why you appreciate them",
        "Smile at yourself in the mirror for 30 seconds",
        "Play your favorite feel-good song",
        "Do a 2-minute dance break",
        "Look through 3 photos that make you smile",
        "Compliment yourself out loud, specifically and genuinely",
        "Step outside and notice one good thing about the weather",
        "Write a short thank-you note to someone, even if you don't send it",
        "Recall your happiest memory from this week in detail",
        "Give yourself a high five and say one thing you're proud of",
        "Hum or sing along to a happy tune",
        "Write down one thing you're looking forward to",
        "Take 5 slow breaths while holding onto this feeling",
        "Do a small kind act, like watering a plant or tidying one spot",
        "Share a funny meme or joke with a friend",
        "Stretch your arms overhead and smile while you do it",
        "Name one small win from today",
        "Write 'I feel happy because...' and finish the sentence",
        "Blow bubbles, doodle, or do something playful for 2 minutes",
    ],
    # ===== ENTHUSIASTIC =====
    "enthusiastic": [
        "List 3 reasons you're fired up about this",
        "Start the first small step of your project right now",
        "Record a voice memo pitching your idea to yourself",
        "Do 10 quick lunges to match your energy",
        "Message a collaborator with your idea",
        "Write a bold, one-sentence mission statement for what you're doing",
        "Set a 3-minute sprint timer and make visible progress on a task",
        "Make a quick checklist of next actions",
        "Clap and say 'let's go' out loud",
        "Sketch a rough plan on paper or in your notes app",
        "Search for one fact or tip related to your interest",
        "Do a power stance for 60 seconds",
        "Write down who could help you and why",
        "Say your goal out loud three times with conviction",
        "Organize your desk or workspace for 3 minutes to prep for action",
        "Rate your enthusiasm 1-10 and write why",
        "Do 20 seconds of fast marching in place",
        "Open a blank note and free-write about your idea for 3 minutes",
        "Set a reminder to revisit this idea tomorrow",
        "Tell someone nearby (or via text) what you're excited to start",
    ],
    # ===== ELATED =====
    "elated": [
        "Jump up and down 10 times, arms raised",
        "Call or voice-message someone to share the moment",
        "Write down this moment so you can remember it later",
        "Do a happy spin or twirl",
        "Take a deep breath and savor the feeling for 60 seconds",
        "Blast your favorite triumphant song for one minute",
        "Write 3 words that capture exactly how you feel",
        "Take a selfie to mark the moment",
        "Do a 30-second victory dance",
        "Thank whoever or whatever contributed to this moment",
        "Star-jump 15 times",
        "Write down what led to this feeling, step by step",
        "Send a celebratory emoji-filled text to a friend",
        "Stand tall, hands on hips, and hold a power pose for 30 seconds",
        "Recall this feeling and rate it 1-10 in a journal",
        "Treat yourself to 2 minutes of your favorite small indulgence",
        "Do a lap of your space while grinning",
        "Say out loud everything you're grateful for right now",
        "Capture a voice note of your laugh or excitement",
        "Plan a tiny celebration for later today",
    ],
    # ===== ENERGETIC =====
    "energetic": [
        "Do 20 jumping jacks",
        "Take a brisk 3-minute walk",
        "Do a 2-minute set of bodyweight squats",
        "Dance hard to one full song",
        "Do a quick set of burpees for 60 seconds",
        "Climb a flight of stairs twice, briskly",
        "Shake out your whole body for 30 seconds",
        "Do high knees in place for 60 seconds",
        "Tackle one physical chore, like making the bed or tidying a shelf",
        "Do a 3-minute HIIT-style set: squats, jumps, punches",
        "Go outside and jog in place or around the block",
        "Do arm circles and stretches for 2 minutes",
        "Channel the energy into organizing one small space",
        "Do 15 push-ups or wall push-ups",
        "Set a 3-minute timer and move nonstop",
        "Do a plank for as long as you can, up to 60 seconds",
        "Walk up and down your stairs for 2 minutes",
        "Punch the air (shadowbox) for 60 seconds",
        "Do jumping rope motions (with or without a rope) for a minute",
        "Put on music and do freestyle movement for 3 minutes",
    ],
    # ===== CALM =====
    "calm": [
        "Take 10 slow, deep breaths",
        "Sip a warm drink slowly and mindfully",
        "Sit quietly and notice 3 sounds around you",
        "Do a slow neck and shoulder stretch",
        "Close your eyes and picture a peaceful place for 2 minutes",
        "Write down one thing you feel settled about",
        "Do a body scan from head to toe, relaxing each part",
        "Sit by a window and watch the outside world for 2 minutes",
        "Light a candle or dim the lights and just sit",
        "Do slow, gentle stretching for 3 minutes",
        "Listen to one calm instrumental track",
        "Trace your breath with your finger on your palm",
        "Rest your hand on your chest and feel it rise and fall",
        "Write a short, unhurried journal entry",
        "Unclench your jaw and drop your shoulders slowly",
        "Do a slow 4-7-8 breathing cycle 4 times",
        "Sit with a cup of tea and do nothing else for 3 minutes",
        "Gently stretch your wrists and hands",
        "Look out a window and name 5 things you see",
        "Simply sit in silence for 2 minutes",
    ],
    # ===== CONTENT =====
    "content": [
        "Write down what's going well right now",
        "Sit and enjoy your current surroundings for 2 minutes",
        "Savor a small snack or drink slowly, paying full attention",
        "List 3 small comforts you have today",
        "Do a slow stretch while reflecting on the day",
        "Write one sentence about why today felt okay",
        "Look around and appreciate one object you own",
        "Sit quietly and enjoy the temperature of the room",
        "Message someone just to say you're doing well",
        "Doodle something simple for 2 minutes",
        "Take a slow walk around your home",
        "Reflect on one thing that's steady and good in your life",
        "Rearrange or tidy one small area you enjoy looking at",
        "Write down a simple pleasure you noticed today",
        "Sit with your pet or a photo of a loved one for 2 minutes",
        "Enjoy a moment of quiet before returning to tasks",
        "Note one thing you're satisfied with about today",
        "Breathe slowly and let yourself feel 'enough' for a minute",
        "Look back at a recent win and enjoy it again",
        "Sit still and simply notice you feel okay",
    ],
    # ===== RELAXED =====
    "relaxed": [
        "Do a slow full-body stretch",
        "Lie down and let your muscles go loose for 2 minutes",
        "Listen to 2 minutes of ambient or nature sounds",
        "Roll your shoulders and neck slowly",
        "Sit back and let your mind wander for 2 minutes",
        "Do a gentle seated forward fold",
        "Close your eyes and breathe slowly for 3 minutes",
        "Massage your own hands or temples for a minute",
        "Loosen your jaw, hands, and shoulders one at a time",
        "Sip water slowly and pay attention to the sensation",
        "Sit in a comfortable position and do nothing for 2 minutes",
        "Let your eyes rest closed for 2 minutes",
        "Do slow leg stretches while seated",
        "Take a warm breath in, and a long slow sigh out, 5 times",
        "Put on soft music and just listen for 2 minutes",
        "Wiggle your fingers and toes slowly to release tension",
        "Recline and place a hand on your stomach, breathing into it",
        "Do a slow child's pose or gentle floor stretch",
        "Let your shoulders drop away from your ears, 5 times",
        "Rest your eyes and just listen to your breathing for 2 minutes",
    ],
    # ===== PEACEFUL =====
    "peaceful": [
        "Sit quietly and watch your breath for 3 minutes",
        "Step outside and notice the sky for 2 minutes",
        "Write down what peace feels like in your body right now",
        "Do a slow walking meditation across the room",
        "Light incense or a candle and sit with the stillness",
        "Listen to birdsong or rain sounds for 2 minutes",
        "Sit cross-legged and rest your hands open on your knees",
        "Repeat a calming word or phrase quietly for a minute",
        "Notice 3 things you can hear right now, one at a time",
        "Sit somewhere quiet and simply exist for 2 minutes",
        "Write one line describing your inner stillness",
        "Do slow, silent breathing with eyes closed for 3 minutes",
        "Watch a candle flame or a plant for 2 minutes",
        "Sit with your palms open, facing up, for a minute",
        "Notice the weight of your body against the chair or floor",
        "Take a mindful sip of water, noticing every sensation",
        "Practice loving-kindness: silently wish yourself well 3 times",
        "Sit near a window and watch clouds or trees move",
        "Breathe in for 4, hold for 4, out for 6, five times",
        "Simply notice you are safe and still, right now",
    ],
    # ===== SERENE =====
    "serene": [
        "Sit in silence and notice the calm in your chest",
        "Do a slow gratitude breath: inhale thanks, exhale tension",
        "Watch natural light move across a wall or floor",
        "Write a single peaceful sentence about this moment",
        "Sit with closed eyes and let thoughts float by without judgment",
        "Hum a slow, quiet tune to yourself",
        "Notice your heartbeat for 60 seconds",
        "Rest your hands in your lap and simply breathe",
        "Look at something beautiful nearby for 2 minutes",
        "Sit and mentally list 3 things you don't need to worry about right now",
        "Do a slow, silent stretch with your eyes closed",
        "Sip something warm in complete silence",
        "Notice the stillness in the room around you",
        "Sit and let your breathing slow naturally for 3 minutes",
        "Write 'right now, I am okay' and sit with that thought",
        "Watch water, a plant, or a candle flicker for 2 minutes",
        "Rest in silence with a soft smile for a minute",
        "Do 5 rounds of slow nostril breathing",
        "Feel your feet on the ground and just notice that for a minute",
        "Sit quietly and let the moment be enough",
    ],
    # ===== ANGRY =====
    "angry": [
        "Do 20 fast punches into the air",
        "Squeeze a pillow or stress ball as hard as you can, 10 times",
        "Write down exactly what's making you angry, no filter",
        "Do 15 jumping jacks to release the charge",
        "Growl or exhale forcefully 5 times",
        "Go for a brisk 2-minute walk, even just around the room",
        "Do 10 push-ups to burn off the intensity",
        "Rip up a piece of scrap paper",
        "Stomp your feet 10 times, hard",
        "Do a wall push for 30 seconds, pushing as hard as you can",
        "Shake your hands and arms out vigorously for 30 seconds",
        "Write an angry letter you'll never send, then tear it up",
        "Do fast high knees for 60 seconds",
        "Splash cold water on your face",
        "Clench and release your fists 10 times, hard",
        "Take 5 sharp exhales through your mouth",
        "Punch a couch cushion a few times",
        "Step away from the situation for 3 minutes and just breathe",
        "Do jumping squats for 60 seconds",
        "Name the anger out loud: 'I am angry because...'",
    ],
    # ===== ANXIOUS =====
    "anxious": [
        "Do the 5-4-3-2-1 grounding exercise (see, hear, feel, smell, taste)",
        "Box breathe: 4 in, 4 hold, 4 out, 4 hold, for 2 minutes",
        "Hold an ice cube or splash cold water on your wrists",
        "Name 3 things in the room that are solid and real",
        "Put one hand on your chest, one on your belly, and breathe slowly",
        "Write down the worry, then write one thing you can control about it",
        "Do a slow body scan, unclenching each muscle group",
        "Count backward from 50 by threes",
        "Press your feet firmly into the floor and notice the sensation",
        "Do a 2-minute progressive muscle relaxation, tensing and releasing",
        "Sip cold water slowly, focusing on the sensation",
        "Say out loud: 'I am safe right now'",
        "Do 10 slow exhales, longer than your inhales",
        "Write down what's the worst that could happen, and how you'd cope",
        "Hum a low, steady tone for 30 seconds",
        "Do a quick stretch of your neck and shoulders",
        "Look around and name 5 colors you can see",
        "Rub your hands together until warm, then cup them over your eyes",
        "Set a timer to worry for exactly 2 minutes, then stop",
        "Text someone you trust just to say hi",
    ],
    # ===== STRESSED =====
    "stressed": [
        "Write down your top 3 stressors in one line each",
        "Do 2 minutes of slow, deep breathing",
        "Make a quick 3-item to-do list to regain a sense of control",
        "Step away from your screen for 3 minutes",
        "Stretch your neck, shoulders, and back for 2 minutes",
        "Do a brain dump: write every thought in your head for 2 minutes",
        "Drink a full glass of water slowly",
        "Do 10 shoulder rolls forward and 10 backward",
        "Pick the single smallest task and just do that one thing",
        "Close your eyes and count 10 slow breaths",
        "Tidy one small surface, like your desk corner",
        "Say out loud what you need most right now",
        "Do a 2-minute walk, even indoors",
        "Write down one thing that can wait until tomorrow",
        "Unclench your jaw and hands 5 times",
        "Do a quick posture reset: sit up, shoulders back, chin level",
        "List one person who could help, even if you don't reach out yet",
        "Take 5 breaths while dropping your shoulders on every exhale",
        "Set a 3-minute timer and do absolutely nothing but breathe",
        "Cross one small thing off any list to build momentum",
    ],
    # ===== IRRITABLE =====
    "irritable": [
        "Step away from the trigger for 2 minutes",
        "Do 10 fast breaths, then 5 slow ones",
        "Squeeze and release your fists 10 times",
        "Write down exactly what's bugging you",
        "Do a quick set of jumping jacks",
        "Put on headphones and listen to one song alone",
        "Splash cool water on your face or wrists",
        "Go to another room for a 2-minute reset",
        "Do 10 shoulder shrugs to release tension",
        "Take 5 slow breaths before responding to anyone",
        "Write 'I need a minute' and give yourself one",
        "Stretch your arms overhead and exhale hard",
        "Do a 60-second stretch focused on your neck and jaw",
        "Drink a glass of water slowly",
        "Step outside for fresh air for 2 minutes",
        "Do 15 seconds of fast shaking out your hands and arms",
        "Name the feeling out loud: 'I feel irritable right now'",
        "Do a quick tidy of one object or space near you",
        "Take a short brisk walk to reset your mood",
        "Write down one thing you need, and one way to get it",
    ],
    # ===== FRUSTRATED =====
    "frustrated": [
        "Step back from the task for 2 minutes",
        "Write down exactly what's not working",
        "Do 10 quick squats to reset your energy",
        "Take 5 deep breaths, focusing on a long exhale",
        "Break the problem into one smaller, doable step",
        "Stretch your hands and wrists, especially if it's screen-related",
        "Walk to another room and back",
        "Say out loud: 'this is frustrating, and that's okay'",
        "Do a 60-second brain dump of every frustration",
        "Shake out your arms and shoulders for 30 seconds",
        "Take a short break and do one unrelated small task",
        "Write down one thing that's actually going right",
        "Do 10 jumping jacks to shift your state",
        "Ask yourself 'what's one small next step?' and write it down",
        "Drink some water and look away from the problem for 2 minutes",
        "Do a slow neck stretch side to side",
        "Set a 3-minute timer to step fully away, then return fresh",
        "Clench your fists for 5 seconds, then release, 5 times",
        "Write down what you'd tell a friend feeling this way",
        "Take 5 long, slow breaths before trying again",
    ],
    # ===== SAD =====
    "sad": [
        "Write down what you're feeling without judging it",
        "Wrap yourself in a blanket for 2 minutes",
        "Message someone you trust just to say hello",
        "Look at a photo of someone or something you love",
        "Do a gentle self-hug for 30 seconds",
        "Write one kind sentence to yourself, like you would to a friend",
        "Step outside for 2 minutes of fresh air",
        "Play one song that matches or soothes your mood",
        "Cry if you need to, and let it pass through you",
        "Drink a warm drink slowly",
        "Do a slow, gentle stretch",
        "Name the sadness out loud: 'I feel sad right now, and that's okay'",
        "Write down one small thing you can look forward to",
        "Pet an animal or hold something soft for 2 minutes",
        "Take 5 slow breaths, letting your shoulders drop",
        "Write a short list of people who care about you",
        "Look out the window for 2 minutes",
        "Do one tiny act of self-care, like washing your face",
        "Sit with your feelings for 2 minutes without trying to fix them",
        "Write down one thing that has helped you feel better before",
    ],
    # ===== BORED =====
    "bored": [
        "Learn one new word and its meaning",
        "Doodle something random for 2 minutes",
        "Rearrange 3 items on your desk or shelf",
        "Look up one interesting fact about a topic you like",
        "Do a quick stretch routine for 2 minutes",
        "Text a friend something random or funny",
        "Try writing your name with your non-dominant hand",
        "Tidy one small drawer or bag",
        "Look out the window and count how many different colors you see",
        "Do 10 jumping jacks just to change your state",
        "Listen to one new song you've never heard",
        "Write a 2-minute stream-of-consciousness journal entry",
        "Try a quick brain teaser or riddle",
        "Reorganize your phone's home screen",
        "Name 5 things you're curious about right now",
        "Fold or organize a small pile of laundry or papers",
        "Draw a quick doodle of whatever's in front of you",
        "Look up a fun fact about a country you've never visited",
        "Do a 2-minute walk somewhere new, even just a different room",
        "Set a challenge: think of 10 uses for a paperclip",
    ],
    # ===== TIRED =====
    "tired": [
        "Close your eyes and rest for 2 minutes, no screens",
        "Drink a full glass of water",
        "Do a gentle stretch to wake up your body slightly",
        "Step outside for fresh air and natural light for 2 minutes",
        "Splash cool water on your face",
        "Do 5 slow, deep breaths to re-oxygenate",
        "Rest your head down for 2 minutes if you're seated",
        "Do a light shoulder and neck roll",
        "Stand up and stretch your arms overhead",
        "Take a short break from your screen and look at something distant",
        "Do a few gentle jumping jacks if you need a light boost",
        "Massage your temples or scalp for a minute",
        "Sit somewhere with natural light for 2 minutes",
        "Do a slow body stretch from head to toe",
        "Take 3 long yawning breaths on purpose",
        "Rest your eyes closed for 90 seconds",
        "Do light ankle and wrist circles to wake up circulation",
        "Step away and lie down flat for 2 minutes if possible",
        "Sip a cold glass of water slowly",
        "Give yourself permission to rest for exactly 3 minutes",
    ],
    # ===== DEPRESSED =====
    "depressed": [
        "Do one small, doable task, like brushing your teeth",
        "Open a curtain or window for natural light",
        "Write down one thing, however small, that you did today",
        "Drink a glass of water",
        "Send one short message to someone you trust",
        "Sit up or change position, even slightly",
        "Wrap yourself in something warm and soft for 2 minutes",
        "Step outside, even just to the doorway, for a minute",
        "Name one basic need you have right now (rest, food, water)",
        "Write down one tiny thing that felt okay today",
        "Do one gentle stretch, even just reaching your arms up",
        "List one person or resource you could reach out to",
        "Play one song, just to have something in the background",
        "Change into more comfortable clothes",
        "Splash water on your face",
        "Sit near a window for 2 minutes",
        "Write 'right now I feel...' and leave it at that, no need to fix it",
        "Do one small act of care, like combing your hair",
        "Set a timer for 2 minutes and just breathe, nothing else required",
        "Note one thing you can do in the next 5 minutes, no more",
    ],
    # ===== GLOOMY =====
    "gloomy": [
        "Open a window or turn on a bright light",
        "Step outside for 2 minutes, even if it's cloudy",
        "Play one upbeat or comforting song",
        "Write down one thing you're grateful for, however small",
        "Do a gentle stretch to shift your physical state",
        "Make a warm drink and hold it in both hands",
        "Look at a photo that brings back a good memory",
        "Message a friend just to check in",
        "Change your immediate surroundings, like moving to another seat",
        "Do 5 slow, deep breaths",
        "Tidy one small area to create a sense of order",
        "Wrap up in a blanket for a couple of minutes",
        "Write down one small thing to look forward to this week",
        "Light a candle or turn on soft lighting",
        "Do a short walk, even indoors",
        "Pet an animal or look at pictures of animals for 2 minutes",
        "Stretch your face muscles: open your mouth wide, then relax",
        "Name one color you find comforting and look for it nearby",
        "Do one small kind thing for yourself, like putting on cozy socks",
        "Write 'this feeling will pass' and sit with that for a minute",
    ],
    # ===== CONFUSED =====
    "confused": [
        "Write down exactly what you're confused about, in one sentence",
        "List what you do know about the situation",
        "List what you don't know, as clear questions",
        "Take 5 slow breaths before trying to think it through",
        "Step away for 2 minutes, then come back with fresh eyes",
        "Draw a simple diagram or map of the situation",
        "Say the problem out loud to yourself",
        "Write down one small next step you could take",
        "Ask yourself 'what's the actual question here?' and write the answer",
        "Break the confusing thing into 2-3 smaller parts",
        "Look up one key term or fact you're unsure about",
        "Write a pros and cons list for whatever you're deciding",
        "Explain the situation as if to a 10-year-old, in writing",
        "Take a short walk to let your mind reset",
        "Talk it through in a voice memo to yourself",
        "Identify one person who might be able to clarify things",
        "Write down your best current guess, even if unsure",
        "Rank your options from most to least likely",
        "Do a quick brain dump of every thought about the topic",
        "Set the confusion aside for 3 minutes and do something else first",
    ],
    # ===== NOSTALGIC =====
    "nostalgic": [
        "Look through 3 old photos and enjoy the memories",
        "Write down one favorite memory in detail",
        "Listen to a song from a meaningful time in your life",
        "Message an old friend just to reconnect",
        "Write a short letter to your younger self",
        "Recall a smell or taste that brings back a memory",
        "Write down 3 things you miss and 3 things you've gained since",
        "Look up an old favorite place on a map",
        "Think of a person from your past and silently thank them",
        "Write one sentence about a lesson that memory taught you",
        "Flip through an old journal, message thread, or playlist",
        "Recreate a small piece of a past routine, like a favorite snack",
        "Write down how you've grown since that memory",
        "Recall your childhood home in vivid detail for 2 minutes",
        "Text someone 'hey, remembered this and thought of you'",
        "Hum a song from an earlier chapter of your life",
        "Write a short 'thank you' to a past version of yourself",
        "Look at an old item you've kept and remember why",
        "Describe an old memory using all 5 senses",
        "Journal about what you'd tell your past self now",
    ],
    # ===== CURIOUS =====
    "curious": [
        "Look up the answer to a question that's on your mind",
        "Read one short article on a topic you're curious about",
        "Write down 3 questions you'd love answered",
        "Watch a 2-minute video on something new",
        "Ask someone nearby (or via text) an interesting question",
        "Explore one new setting on your phone or app you've never touched",
        "Look up the origin of a word you use often",
        "Try a tiny experiment, like tasting something new or trying a new route",
        "Write a list of 5 things you'd like to learn someday",
        "Look up a fact about the place you're currently in",
        "Search for how something around you actually works",
        "Read the first paragraph of a Wikipedia article on a random topic",
        "Ask 'why' about something ordinary and try to answer it",
        "Flip through a book or app you haven't opened in a while",
        "Look up a quick fact about a historical event today",
        "Try learning one phrase in a new language",
        "Write a question you don't know the answer to, then research it",
        "Explore a new song, artist, or genre for 2 minutes",
        "Look up what's directly above or below where you're standing",
        "Note one thing you noticed today that you'd never noticed before",
    ],
    # ===== INDIFFERENT =====
    "indifferent": [
        "Do one small, simple task just to build momentum",
        "Write down what, if anything, would interest you right now",
        "Step outside for a change of scenery for 2 minutes",
        "Do a quick stretch to shift your physical state",
        "Try one new small thing, like a different drink or route",
        "Write down one thing you used to enjoy",
        "Play a song you haven't heard in a while",
        "Do 10 jumping jacks just to notice how your body responds",
        "List 3 things you're neutral about and 3 you actually like",
        "Message a friend, even with something small",
        "Tidy one small area to create some sense of progress",
        "Look around and name one object you find mildly interesting",
        "Try switching tasks to something slightly different",
        "Take 5 slow breaths and check in with your body",
        "Write 'right now I feel...' and just observe, no pressure to change it",
        "Do a short walk to see if it shifts anything",
        "Pick one tiny task from your list and just start it",
        "Notice one sensation in your body right now",
        "Write down one thing you're mildly curious about",
        "Do something with your hands, like doodling or folding paper",
    ],
    # ===== SURPRISED =====
    "surprised": [
        "Take 5 slow breaths to steady yourself",
        "Write down what just surprised you, in one line",
        "Sit down for a moment before reacting further",
        "Say out loud, 'okay, that was unexpected'",
        "Drink a glass of water to ground yourself",
        "Write down your first honest reaction",
        "Take a moment of stillness before deciding what to do next",
        "List what you now know that you didn't a moment ago",
        "Message someone to share the surprising news",
        "Do a quick body check: are your shoulders tense? Relax them",
        "Write down one question this surprise raises for you",
        "Take a short walk to process what happened",
        "Pause and name the emotion underneath the surprise (excited? worried?)",
        "Do 5 slow exhales to settle your nervous system",
        "Write one sentence about what you'll do next",
        "Sit quietly for a minute and let the news sink in",
        "Ask yourself if this changes anything urgent, or if it can wait",
        "Jot down the facts as you understand them right now",
        "Take a moment to consider both the good and hard sides of it",
        "Give yourself permission to respond later, not immediately",
    ],
}

VARIANTS = [
    "",                          # base
    " (do it slowly and mindfully)",
    " while sitting comfortably",
    " while standing",
    " with your eyes closed if possible",
]

# ---------------------------------------------------------------- build

ACTIONS = []
for mood in MOODS:
    for task in BASE_TASKS[mood]:
        for suffix in VARIANTS:
            title = task + suffix
            cat, sub = _categorize(mood, title)
            ACTIONS.append({
                "title": title,
                "description": task,
                "category": cat,
                "sub_category": sub,
                "estimated_minutes": _est_minutes(task, mood),
                "difficulty": _difficulty(task, mood),
                "required_energy": "low" if mood in (
                    "calm", "relaxed", "peaceful", "serene", "content",
                    "sad", "bored", "tired", "depressed", "gloomy",
                ) else "medium",
                "mood_tags": [mood],
                "situation_tags": ["motivation", "other"],
                "base_xp": 10,
            })

# dedup
seen = set()
unique = []
for a in ACTIONS:
    if a["title"] not in seen:
        seen.add(a["title"])
        unique.append(a)
ACTIONS = unique

# ---------------------------------------------------------------- main

def main():
    for a in ACTIONS:
        assert 1 <= a["difficulty"] <= 5
        assert a["required_energy"] in ("low", "medium", "high")
        assert len(a["mood_tags"]) == 1

    seed = ROOT / "supabase" / "seed"
    seed.mkdir(parents=True, exist_ok=True)

    with (seed / "actions.json").open("w") as f:
        json.dump(ACTIONS, f, indent=2)

    rows = []
    for a in ACTIONS:
        mood = "{" + ",".join(a["mood_tags"]) + "}"
        situ = "{" + ",".join(a["situation_tags"]) + "}"
        title = a["title"].replace("'", "''")
        desc = a["description"].replace("'", "''")
        rows.append(
            "('{title}', '{desc}', '{cat}', '{sub}', {mins}, {diff}, '{energy}', "
            "'{mood}'::text[], '{situ}'::text[], {xp}, true)"
            .format(
                title=title, desc=desc, cat=a["category"], sub=a["sub_category"],
                mins=a["estimated_minutes"], diff=a["difficulty"],
                energy=a["required_energy"], mood=mood, situ=situ, xp=a["base_xp"],
            )
        )

    sql = "\n".join([
        "-- 1% Better action library seed. Repeatable: on conflict (title) do nothing.",
        "-- Re-running never duplicates actions and never touches user data.",
        "",
        "insert into public.actions",
        "  (title, description, category, sub_category, estimated_minutes, difficulty,",
        "   required_energy, mood_tags, situation_tags, base_xp, active)",
        "values",
        ",\n".join(rows),
        "on conflict (title) do nothing;",
        "",
    ])
    with (seed / "seed_actions.sql").open("w") as f:
        f.write(sql)

    print(f"wrote {len(ACTIONS)} actions -> supabase/seed/actions.json and seed_actions.sql")


if __name__ == "__main__":
    main()
