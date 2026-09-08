#!/usr/bin/env python3
"""Generate supabase/seed/actions.json and supabase/seed/seed_actions.sql.

Repeatable: uses ON CONFLICT (title) DO NOTHING so re-running never duplicates,
overwrites user history, or deletes user data. Adding new actions later is just
adding entries here and re-running.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# mood tag vocabulary: excited, happy, enthusiastic, elated, energetic,
#                       calm, content, relaxed, peaceful, serene,
#                       angry, anxious, stressed, irritable, frustrated,
#                       sad, bored, tired, depressed, gloomy,
#                       confused, nostalgic, curious, indifferent, surprised
# situation vocabulary: school, work, family, friends, relationships, money,
#                       loneliness, stress, motivation, other

# Legacy → new tag remap (old 5-mood set), applied in act() so the generated
# seed stays in sync with the expanded mood vocabulary.
_LEGACY_MOODS = {
    "great": "excited",
    "good": "happy",
    "okay": "confused",
    "low": "sad",
    "stressed": "stressed",
}


def act(title, desc, cat, sub, mins, diff, energy, moods, situ, xp=None):
    if xp is None:
        xp = 10 if diff <= 2 else (15 if diff <= 3 else 20)
    return {
        "title": title,
        "description": desc,
        "category": cat,
        "sub_category": sub,
        "estimated_minutes": mins,
        "difficulty": diff,
        "required_energy": energy,
        "mood_tags": [_LEGACY_MOODS.get(m, m) for m in moods],
        "situation_tags": situ,
        "base_xp": xp,
    }


ACTIONS = []

# ---------------------------------------------------------------- wellbeing
B = "wellbeing"
ACTIONS += [
    act("Take Five Slow Breaths", "Take five slow breaths and focus only on your breathing.", B, "breathing", 2, 1, "low", ["stressed", "low"], ["stress", "school", "work"]),
    act("Breathe in a Box", "Breathe in for 4, hold for 4, out for 4, rest for 4. Repeat four times.", B, "breathing", 3, 1, "low", ["stressed", "low"], ["stress", "school", "work"]),
    act("Try the 4-7-8 Breath", "Breathe in for 4 seconds, hold for 7, exhale slowly for 8. Repeat four times.", B, "breathing", 4, 2, "low", ["stressed"], ["stress", "work", "school"]),
    act("Breathe with Your Belly", "Place a hand on your belly and breathe so your hand rises and falls slowly.", B, "breathing", 3, 1, "low", ["stressed", "low"], ["stress"]),
    act("Exhale Twice as Long", "For two minutes, make each exhale twice as long as your inhale.", B, "breathing", 2, 1, "low", ["stressed", "okay"], ["stress", "work"]),
    act("Listen to Your Breath", "Close your eyes and listen to the sound of your own breathing for one minute.", B, "breathing", 2, 1, "low", ["stressed", "low"], ["stress"]),
    act("Hum to Soothe", "Exhale while humming softly. Feel the vibration calm your chest.", B, "breathing", 3, 2, "low", ["stressed", "low"], ["stress", "loneliness"]),
    act("Count Ten Slow Breaths", "Count ten breaths, slow and even, without rushing any of them.", B, "breathing", 4, 1, "low", ["stressed", "low"], ["stress"]),
    act("Name Five Things You See", "Look around and name five things you can see right now.", B, "grounding", 2, 1, "low", ["stressed", "low"], ["stress", "other"]),
    act("Feel Three Things", "Notice three physical sensations: the chair, the floor, the air on your skin.", B, "grounding", 2, 1, "low", ["stressed", "low"], ["stress"]),
    act("Use the 5-4-3-2-1 Senses", "Name 5 things you see, 4 you feel, 3 you hear, 2 you smell, 1 you taste.", B, "grounding", 4, 2, "low", ["stressed", "low"], ["stress"]),
    act("Plant Your Feet", "Stand or sit, press both feet into the ground, and notice the pressure for a minute.", B, "grounding", 1, 1, "low", ["stressed", "low"], ["stress"]),
    act("Touch Something Textured", "Find a textured object and run your fingers over it slowly, paying full attention.", B, "grounding", 2, 1, "low", ["stressed"], ["stress", "other"]),
    act("Take a Cold Sip", "Drink a glass of cold water slowly, noticing the temperature.", B, "grounding", 2, 1, "low", ["stressed", "okay"], ["stress"]),
    act("Say the Date Out Loud", "Say today's date, the day, and one true fact about this moment out loud.", B, "grounding", 1, 1, "low", ["stressed", "low"], ["stress"]),
    act("Name Three Sounds Around You", "Stop and name three sounds you can hear right now.", B, "grounding", 2, 1, "low", ["stressed", "low"], ["stress"]),
    act("Scan Your Body Quickly", "From head to toe, notice where you hold tension for 20 seconds each spot.", B, "relaxation", 5, 2, "low", ["stressed", "low"], ["stress"]),
    act("Tense and Release Your Shoulders", "Shrug your shoulders up for 5 seconds, then drop and release. Repeat three times.", B, "relaxation", 3, 1, "low", ["stressed", "low"], ["stress", "work"]),
    act("Soften Your Jaw", "Unclench your jaw, lower your tongue, and let your face relax.", B, "relaxation", 1, 1, "low", ["stressed"], ["stress", "work"]),
    act("Progressive Muscle Relax", "Tense each muscle group for 5 seconds, then release, moving down your body.", B, "relaxation", 8, 3, "low", ["stressed", "low"], ["stress"]),
    act("Rest Your Eyes", "Close your eyes and let them rest for two full minutes.", B, "relaxation", 2, 1, "low", ["low", "stressed"], ["stress", "school", "work"]),
    act("Do Nothing for Three Minutes", "Set a timer for three minutes and simply sit without a task.", B, "relaxation", 3, 1, "low", ["stressed", "low"], ["stress", "motivation"]),
    act("Loosen Your Hands", "Shake out both hands loosely for thirty seconds and notice how it feels.", B, "relaxation", 1, 1, "low", ["stressed"], ["work", "school"]),
    act("Write One Thing That Went Well", "Write down one small thing that went well today.", B, "gratitude", 3, 1, "low", ["low", "okay"], ["motivation", "loneliness"]),
    act("Say Thanks for Three Small Things", "Mentally thank three small things: hot water, daylight, a good chair.", B, "gratitude", 3, 1, "low", ["low", "okay"], ["motivation"]),
    act("Text a Simple Thank You", "Send a short thank-you message to someone who helped you recently.", B, "gratitude", 5, 2, "low", ["good", "okay"], ["friends", "family"]),
    act("Recall a Kind Memory", "Remember one kind moment from the past week and replay it in detail.", B, "gratitude", 4, 2, "low", ["low", "okay"], ["loneliness", "motivation"]),
    act("List What You Have Today", "List three things you have right now that you sometimes take for granted.", B, "gratitude", 4, 1, "low", ["low", "okay"], ["motivation", "money"]),
    act("Thank Someone Out Loud", "Tell someone face to face one specific thing you appreciate about them.", B, "gratitude", 3, 3, "medium", ["good"], ["friends", "family"]),
    act("Soothe Yourself with Kind Words", "Say to yourself: 'This is hard, and I'm doing my best.'", B, "self-soothing", 2, 1, "low", ["low", "stressed"], ["stress", "school", "work"]),
    act("Wrap Yourself in a Blanket", "Wrap a blanket around yourself for a few minutes and breathe slowly.", B, "self-soothing", 5, 1, "low", ["low", "stressed"], ["loneliness", "stress"]),
    act("Make a Warm Drink", "Make a warm drink and hold the cup with both hands, sipping slowly.", B, "self-soothing", 6, 1, "low", ["low", "okay"], ["loneliness", "stress"]),
    act("Play Something Gentle", "Play one gentle song you like and give it your full attention.", B, "self-soothing", 4, 1, "low", ["low", "stressed"], ["stress", "loneliness"]),
    act("Stretch Your Neck Gently", "Slowly tilt your head side to side, staying soft and easy.", B, "relaxation", 3, 1, "low", ["stressed"], ["work", "school"]),
]

# ---------------------------------------------------------------- productivity
P = "productivity"
ACTIONS += [
    act("Pick One Task for Today", "Choose exactly one task that matters and write it down.", P, "planning", 3, 1, "low", ["okay", "good"], ["work", "school", "motivation"]),
    act("Write a Five-Item To-Do List", "Write down five tasks, then circle the single most important one.", P, "planning", 5, 2, "low", ["okay", "good"], ["work", "school", "motivation"]),
    act("Plan Your Top Three", "Write the three most important things to do today, in order.", P, "planning", 5, 2, "low", ["good", "okay"], ["work", "school"]),
    act("Set One Time Block", "Reserve one 25-minute block for your most important task.", P, "planning", 3, 2, "low", ["okay"], ["work", "school", "motivation"]),
    act("Write Tomorrow's Plan Tonight", "Tonight, write the first task you'll start with tomorrow.", P, "planning", 4, 2, "low", ["okay", "low"], ["work", "school", "motivation"]),
    act("Decide the Next Step Only", "For your biggest task, write down only the very next physical step.", P, "planning", 4, 2, "low", ["low", "okay"], ["motivation", "work", "school"]),
    act("Break a Task into Three Pieces", "Take one task you're avoiding and split it into three small pieces.", P, "task breakdown", 5, 3, "medium", ["low", "okay"], ["motivation", "work", "school"]),
    act("Start With Two Minutes", "Spend just two minutes starting the task you're avoiding.", P, "task breakdown", 2, 2, "low", ["low", "okay"], ["motivation", "work", "school"]),
    act("Do One Micro-Task", "Complete the smallest useful piece of your big project.", P, "task breakdown", 5, 2, "low", ["okay"], ["work", "school", "motivation"]),
    act("Estimate How Long It Really Takes", "Guess how long your task takes, then check how close you were.", P, "task breakdown", 4, 2, "low", ["good"], ["work", "school"]),
    act("Clear Your Desk of One Thing", "Put away one thing that is cluttering your workspace.", P, "organization", 3, 1, "low", ["okay", "good"], ["work", "school"]),
    act("Close Ten Extra Tabs", "Close the ten browser tabs you no longer need.", P, "organization", 3, 1, "low", ["good", "okay"], ["work", "school", "motivation"]),
    act("Sort Your Inbox Once", "Open your inbox and decide the fate of ten messages: reply, file, or delete.", P, "organization", 10, 3, "medium", ["good", "okay"], ["work"]),
    act("Silence Non-Essential Notifications", "Turn off notifications for apps you don't need for the next hour.", P, "organization", 3, 1, "low", ["okay"], ["work", "school"]),
    act("Make Your Bed", "Make your bed before anything else today.", P, "organization", 3, 1, "low", ["okay", "good"], ["motivation", "other"]),
    act("Write Your Today Theme", "Give today a one-word theme, like 'calm' or 'steady'.", P, "planning", 2, 1, "low", ["okay", "low"], ["motivation"]),
    act("Focus for Ten Minutes", "Focus on one thing for ten uninterrupted minutes.", P, "focus", 10, 2, "medium", ["good", "okay"], ["work", "school", "motivation"]),
    act("Use the One-Tab Rule", "Work on one tab, one window, one task for 20 minutes.", P, "focus", 20, 3, "medium", ["good"], ["work", "school"]),
    act("Turn Off Your Phone", "Switch your phone to airplane mode for 30 minutes and do one thing.", P, "focus", 30, 3, "medium", ["good", "okay"], ["work", "school", "motivation"]),
    act("Try the Pomodoro First Round", "Set a 25-minute timer, work on one task, then take a 5-minute break.", P, "focus", 30, 3, "medium", ["good"], ["work", "school"]),
    act("Move Your Phone to Another Room", "Leave your phone in another room for the next 30 minutes.", P, "focus", 30, 2, "low", ["good", "okay"], ["work", "school", "motivation"]),
    act("Write One Paragraph", "Write one paragraph toward the thing you keep postponing.", P, "focus", 8, 3, "medium", ["low", "okay"], ["motivation", "work", "school"]),
]

# ---------------------------------------------------------------- study
S = "study"
ACTIONS += [
    act("Review Your Notes for Five Minutes", "Read through today's or yesterday's notes for five minutes.", S, "revision", 5, 2, "low", ["good", "okay"], ["school"]),
    act("Summarise One Page in One Sentence", "Summarise one page of notes into a single sentence.", S, "revision", 5, 3, "medium", ["okay"], ["school"]),
    act("Quiz Yourself on Three Facts", "Cover your notes and recall three key facts from memory.", S, "revision", 5, 3, "medium", ["good", "okay"], ["school"]),
    act("Teach One Idea Aloud", "Explain one concept out loud as if teaching a friend.", S, "revision", 6, 3, "medium", ["good"], ["school"]),
    act("Re-read One Section Slowly", "Re-read one section of your material and highlight three key points.", S, "revision", 8, 2, "low", ["okay"], ["school"]),
    act("Write Three Revision Questions", "Write three questions your teacher might ask on the exam.", S, "revision", 8, 3, "medium", ["okay", "good"], ["school"]),
    act("Make a One-Week Revision Plan", "Sketch which subjects you'll revise on each of the next seven days.", S, "exam planning", 10, 3, "medium", ["good"], ["school", "stress"]),
    act("List What the Exam Covers", "Write down every topic the exam covers, then mark your weakest two.", S, "exam planning", 8, 3, "medium", ["okay"], ["school", "stress"]),
    act("Pick Your Weakest Topic", "Choose your single weakest topic and open its notes.", S, "exam planning", 5, 2, "low", ["low", "okay"], ["school", "stress"]),
    act("Start With the Easy Marks", "Identify which exam sections earn marks for basic recall and plan to secure them first.", S, "exam planning", 8, 3, "medium", ["good"], ["school"]),
    act("Plan Your Exam Morning", "Write down what you'll do the morning of the exam, step by step.", S, "exam planning", 6, 2, "low", ["stressed"], ["school", "stress"]),
    act("Use Flashcards for Three Terms", "Make flashcards for three terms you keep forgetting.", S, "memory", 8, 2, "low", ["okay", "good"], ["school"]),
    act("Remember a List With a Story", "Turn a list you need to memorise into a short, silly story.", S, "memory", 6, 2, "low", ["good"], ["school"]),
    act("Test Yourself, Then Check", "Recall five things from memory, then check your notes for accuracy.", S, "memory", 6, 2, "medium", ["okay"], ["school"]),
    act("Space Your Revision", "Revise one topic today, and schedule the same topic again in two days.", S, "memory", 5, 2, "low", ["good"], ["school"]),
    act("Draw a Simple Diagram", "Turn one concept into a simple diagram from memory.", S, "memory", 7, 3, "medium", ["good", "okay"], ["school"]),
    act("Rewrite Notes in Your Own Words", "Rewrite one page of notes using your own words only.", S, "note-taking", 10, 3, "medium", ["okay"], ["school"]),
    act("Add One Question to Your Notes", "Write one question in the margin of your notes that you can't answer yet.", S, "note-taking", 4, 2, "low", ["okay"], ["school"]),
    act("Use the Cornell Layout", "Split a page into notes and keywords, and fill one section.", S, "note-taking", 10, 3, "medium", ["good"], ["school"]),
    act("Highlight Only Three Lines", "Take a dense page and highlight only the three most important lines.", S, "note-taking", 6, 2, "low", ["okay"], ["school"]),
    act("Write One Question Per Section", "For each section of your notes, write one question the section answers.", S, "note-taking", 8, 3, "medium", ["good"], ["school"]),
]

# ---------------------------------------------------------------- social
SOC = "social"
ACTIONS += [
    act("Message One Friend", "Send one short message to a friend just to say hi.", SOC, "message", 3, 2, "low", ["lonely", "okay"], ["loneliness", "friends"]),
    act("Reply to a Stale Message", "Reply to one message you've been meaning to answer.", SOC, "message", 4, 2, "low", ["okay"], ["friends", "family"]),
    act("Ask Someone How They Are", "Text someone and ask how they're actually doing.", SOC, "message", 3, 2, "low", ["good"], ["friends", "loneliness"]),
    act("Send One Voice Note", "Send a quick voice note to a friend instead of a text.", SOC, "message", 3, 2, "low", ["good", "okay"], ["friends", "loneliness"]),
    act("Call Someone for Ten Minutes", "Call a friend or family member and talk for ten minutes.", SOC, "message", 10, 4, "high", ["lonely", "okay"], ["loneliness", "family", "friends"]),
    act("Ask a Friend for Help", "Ask one person for help with something specific today.", SOC, "ask-help", 5, 3, "medium", ["low", "okay"], ["friends", "work", "school", "stress"]),
    act("Tell Someone What You Need", "Tell one person, clearly, what you need right now.", SOC, "ask-help", 5, 4, "medium", ["low", "okay"], ["family", "friends", "stress"]),
    act("Share How You're Feeling", "Tell one trusted person honestly how you're feeling today.", SOC, "ask-help", 5, 4, "medium", ["low", "stressed"], ["friends", "family", "loneliness"]),
    act("Ask for a Second Opinion", "Run a small decision by someone you trust.", SOC, "ask-help", 5, 2, "low", ["okay"], ["work", "school", "friends"]),
    act("Thank a Friend Specifically", "Tell a friend one specific thing they did that helped you.", SOC, "thank", 3, 2, "low", ["good"], ["friends", "family"]),
    act("Leave a Compliment", "Give one sincere compliment to someone today.", SOC, "thank", 2, 2, "low", ["good"], ["friends", "family", "work"]),
    act("Send a Message of Encouragement", "Send one encouraging message to someone who is struggling.", SOC, "encourage", 4, 2, "low", ["good"], ["friends", "loneliness"]),
    act("Celebrate Someone's Win", "Congratulate someone on a recent win, big or small.", SOC, "encourage", 3, 1, "low", ["good"], ["friends", "family", "work"]),
    act("Make a Small Offer of Help", "Offer help to someone for one small thing today.", SOC, "encourage", 3, 2, "low", ["good"], ["friends", "family"]),
    act("Invite Someone to Do Something Small", "Invite a friend to a walk, a coffee, or a short call.", SOC, "message", 5, 3, "medium", ["good", "okay"], ["friends", "loneliness"]),
    act("Check on Someone Quiet", "Message someone you haven't heard from in a while, no agenda.", SOC, "encourage", 4, 2, "low", ["good"], ["friends", "loneliness"]),
    act("Introduce Two People", "Introduce two people who could help each other.", SOC, "encourage", 5, 3, "medium", ["good"], ["work", "friends"]),
    act("Say Good Morning to a Neighbour", "Greet someone in your building or street warmly.", SOC, "message", 2, 2, "low", ["good"], ["loneliness", "other"]),
    act("Reconnect With an Old Friend", "Send one message to an old friend you've lost touch with.", SOC, "message", 4, 3, "medium", ["okay", "lonely"], ["loneliness", "friends"]),
    act("Listen Fully to Someone", "Give someone your full attention for ten minutes without interrupting.", SOC, "encourage", 10, 3, "medium", ["good"], ["friends", "family"]),
]

# ---------------------------------------------------------------- physical
PH = "physical"
ACTIONS += [
    act("Stretch Your Back Slowly", "Stand up and stretch your back gently for two minutes.", PH, "stretching", 2, 1, "low", ["okay", "stressed"], ["work", "school"]),
    act("Touch Your Toes Five Times", "Reach for your toes, hold five seconds, and come up slowly. Repeat five times.", PH, "stretching", 5, 2, "medium", ["okay"], ["work", "school"]),
    act("Roll Your Shoulders", "Roll your shoulders backward ten times, then forward ten times.", PH, "stretching", 2, 1, "low", ["stressed"], ["work", "school"]),
    act("Do a Doorway Stretch", "Place your hands on a doorframe and lean through to open your chest.", PH, "stretching", 3, 2, "low", ["okay"], ["work", "school"]),
    act("Stretch Your Neck Slowly", "Gently move your head side to side and chin to chest for a minute.", PH, "stretching", 2, 1, "low", ["stressed"], ["work", "school"]),
    act("Do a Full-Body Unwind", "Stretch your neck, shoulders, back, legs, and wrists for five minutes.", PH, "stretching", 5, 2, "low", ["stressed", "okay"], ["work", "school"]),
    act("Walk for Ten Minutes", "Take a short ten-minute walk outside.", PH, "walking", 10, 2, "medium", ["low", "okay"], ["stress", "loneliness"]),
    act("Walk and Notice the Weather", "Take a five-minute walk and notice the temperature and light.", PH, "walking", 5, 1, "low", ["low", "okay"], ["stress"]),
    act("Take the Stairs", "Use the stairs instead of the lift once today.", PH, "walking", 3, 2, "medium", ["good"], ["other", "work", "school"]),
    act("Walk to a New Spot", "Walk somewhere you've never walked before, even just around the block.", PH, "walking", 15, 3, "medium", ["good", "okay"], ["loneliness", "stress"]),
    act("Walk One Errand on Foot", "Do one nearby errand on foot instead of by car or bus.", PH, "walking", 15, 3, "medium", ["good"], ["other"]),
    act("March in Place for a Minute", "March in place, lifting knees, for one minute to get your blood moving.", PH, "movement", 1, 1, "low", ["okay"], ["work", "school", "motivation"]),
    act("Do Ten Squats", "Do ten slow, controlled squats at your own pace.", PH, "movement", 3, 3, "medium", ["good"], ["other", "work"]),
    act("Dance to One Song", "Dance freely to one full song, alone if that feels right.", PH, "movement", 4, 2, "medium", ["good", "okay"], ["motivation", "other"]),
    act("Do Five Push-Ups", "Do five push-ups, on your knees if needed.", PH, "movement", 3, 3, "medium", ["good"], ["other"]),
    act("Move Your Body for Two Minutes", "Jump, stretch, wiggle, or walk for two continuous minutes.", PH, "movement", 2, 2, "low", ["low", "okay"], ["motivation", "work", "school"]),
    act("Lift Something Light Ten Times", "Pick a light weight (or a bottle of water) and lift it ten times each side.", PH, "movement", 3, 2, "low", ["good"], ["work", "other"]),
    act("Drink a Full Glass of Water", "Drink a full glass of water slowly, right now.", PH, "water", 2, 1, "low", ["okay", "low"], ["stress", "work", "school"]),
    act("Refill Your Water Bottle", "Fill your water bottle and set it where you'll see it.", PH, "water", 2, 1, "low", ["okay"], ["work", "school"]),
    act("Drink Water Before Each Meal", "Drink a glass of water before each meal today.", PH, "water", 2, 1, "low", ["good"], ["other"]),
    act("Swap One Drink for Water", "Swap your next sugary or caffeinated drink for water.", PH, "water", 1, 2, "low", ["good"], ["other"]),
    act("Close Your Eyes for Five Minutes", "Lie down, close your eyes, and rest fully for five minutes.", PH, "rest", 5, 1, "low", ["low", "stressed"], ["stress", "work", "school"]),
    act("Rest Your Eyes From Screens", "Look away from every screen for three minutes.", PH, "rest", 3, 1, "low", ["stressed", "okay"], ["work", "school"]),
    act("Take a Ten-Minute Power Nap", "Nap for no more than ten minutes, then get up and move.", PH, "rest", 10, 2, "low", ["low"], ["work", "school", "stress"]),
    act("Go to Bed a Little Earlier", "Go to bed twenty minutes earlier than usual tonight.", PH, "rest", 20, 3, "low", ["low"], ["stress", "school", "work"]),
    act("Do Nothing Active for One Hour", "Give yourself one screen-free hour of true rest this evening.", PH, "rest", 60, 2, "low", ["low", "stressed"], ["stress"]),
]

# ---------------------------------------------------------------- reflection
R = "reflection"
ACTIONS += [
    act("Write Three Lines About Today", "Write three honest lines about how today has been.", R, "journaling", 5, 2, "low", ["okay", "low"], ["motivation", "stress"]),
    act("Write a Free Page", "Write freely for five minutes without stopping or judging.", R, "journaling", 5, 2, "low", ["low", "stressed"], ["stress", "other"]),
    act("Write One Worry and One Hope", "Write down one worry and one hope for this week.", R, "journaling", 5, 2, "low", ["low", "stressed"], ["stress", "school", "work"]),
    act("Write a Letter You Won't Send", "Write a letter to someone about how you feel. You don't have to send it.", R, "journaling", 10, 3, "medium", ["low", "stressed"], ["family", "friends", "relationships"]),
    act("Write About a Happy Moment", "Describe one happy moment from this week in as much detail as you can.", R, "journaling", 8, 2, "low", ["low", "okay"], ["motivation"]),
    act("Keep a One-Question Journal", "Answer: 'What would make today a little better?'", R, "journaling", 4, 1, "low", ["okay", "low"], ["motivation"]),
    act("Name Your Feeling Precisely", "Write the exact word for what you feel right now, beyond 'fine'.", R, "feelings", 3, 2, "low", ["low", "stressed"], ["stress", "other"]),
    act("Rate Your Feelings", "Rate how you feel from 1 to 10, then write why it isn't lower.", R, "feelings", 4, 2, "low", ["low", "okay"], ["stress"]),
    act("Ask Where It Comes From", "Pick one strong feeling and write what might be triggering it.", R, "feelings", 6, 3, "medium", ["low", "stressed"], ["stress", "family", "work"]),
    act("Notice the Feeling in Your Body", "Write where you feel your current emotion in your body, without judging it.", R, "feelings", 4, 2, "low", ["low", "stressed"], ["stress"]),
    act("Name Three Feelings You Had Today", "List three different feelings you experienced today.", R, "feelings", 3, 2, "low", ["okay"], ["other"]),
    act("List What You Can Control", "Write three things you can control today and one you can't.", R, "control", 5, 2, "low", ["stressed", "low"], ["stress", "school", "work", "family"]),
    act("Sort Worries Into Two Piles", "Write your worries in two lists: changeable and not changeable today.", R, "control", 6, 3, "medium", ["stressed"], ["stress", "work", "school", "money"]),
    act("Pick One Controllable Action", "Choose one small action within your control and commit to it today.", R, "control", 4, 2, "low", ["okay", "low"], ["motivation", "stress"]),
    act("Write Your Boundary", "Write one boundary you want to set or hold this week.", R, "control", 5, 3, "medium", ["stressed", "low"], ["family", "friends", "relationships", "work"]),
    act("Decide What to Let Go Of", "Write one thing you will stop trying to control this week.", R, "control", 4, 2, "low", ["stressed", "low"], ["stress", "family"]),
    act("Write Tomorrow's First Step", "Write the first step you'll take tomorrow, and when.", R, "plan-tomorrow", 4, 2, "low", ["okay", "low"], ["motivation", "school", "work"]),
    act("Write One Good Thing About Today", "Write one thing you want to remember about today.", R, "plan-tomorrow", 3, 1, "low", ["okay", "low"], ["motivation"]),
    act("Plan One Energising Thing", "Plan one small thing you enjoy into tomorrow.", R, "plan-tomorrow", 4, 1, "low", ["low", "okay"], ["motivation", "stress"]),
    act("Set Tomorrow's Intention", "Write one intention for how you want tomorrow to feel.", R, "plan-tomorrow", 3, 1, "low", ["okay"], ["motivation"]),
    act("Preview Tomorrow's Schedule", "Write tomorrow's schedule in three lines: morning, midday, evening.", R, "plan-tomorrow", 6, 2, "low", ["stressed"], ["school", "work", "stress"]),
    act("List Three Wins From This Week", "Write three things you finished or handled this week.", R, "achievements", 4, 1, "low", ["low", "okay"], ["motivation"]),
    act("Write What You Learned", "Write one lesson you learned from a recent mistake.", R, "achievements", 5, 2, "low", ["okay"], ["other", "work", "school"]),
    act("Note How Far You've Come", "Compare where you were a month ago to where you are now.", R, "achievements", 6, 2, "low", ["low", "okay"], ["motivation"]),
    act("Give Yourself Credit", "Write one thing you did today that took courage or care.", R, "achievements", 3, 1, "low", ["low", "okay"], ["motivation"]),
    act("Write Your Top Five Strengths", "Write down five strengths you know you have.", R, "achievements", 4, 1, "low", ["low"], ["motivation", "loneliness"]),
]


def main():
    seen = set()
    for a in ACTIONS:
        assert a["title"] not in seen, f"duplicate title: {a['title']}"
        seen.add(a["title"])
        assert 1 <= a["difficulty"] <= 5
        assert a["required_energy"] in ("low", "medium", "high")

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

    sql = "\n".join(
        [
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
        ]
    )
    with (seed / "seed_actions.sql").open("w") as f:
        f.write(sql)

    print(f"wrote {len(ACTIONS)} actions -> supabase/seed/actions.json and seed_actions.sql")


if __name__ == "__main__":
    main()
