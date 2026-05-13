So, I will explain the working of this app and this project. You need to check our current code is doing what exactly I am intending. 

So, the idea is this is a dating platform—not a dating platform, you know, like a dating platform. So, let me share the concept first.

So, our app's name is Hamme. So, consider I am an Instagram user or Snapchat user, and I installed this Hamme app. And I'm registering here with my Instagram ID and age and username and my date of birth over here, age. You know the polls in their stories and people post stories asking questions and like... So we are creating a separate platform for asking these questions. 

Our user, our customer, create a question—not exactly creating, the question is already there. They just share a link to—from our app Hamme, we provide a link to this question. And this user can share it and post on their Instagram page, this link.

And when other Instagram user see this story, they click on this link. And when they click on this link, we launch them into a web browser. And there they can see the question. 

For example, the question is here, the Instagram creator asking: "Is you my crush or friend?" 

And in the browser, I can answer "friend" or "crush." Then click on reveal. To reveal means to get the response from the creator. This question works both ways:
1. Creator can choose that the user is my crush or friend. 
2. Also, this user can choose that the creator is his crush or friend.

And we don't reveal this to both. If these two responses are same, then in the app, there is a match tab; there we show this matched. The idea is that. you two are matched

And let's check and verify all the features currently in the creator are working or not.

One bug I found is I created a profile as a creator and I shared a poll. When I run the another app for the another user—and currently the deep link feature is not implemented, so we are only showing an input box to paste the deep link so we can identify the creator temporarily—when I do that, after completing the profile, these both users have same link in their profile. 

But that is not how it works. He needs his own link, and this new user needs his own link for sharing his code. That link is used by other users to vote.

Find the similar bugs and fix all, or first report me all the bugs in this and the functionalities are working or not as intended.